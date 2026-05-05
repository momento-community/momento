import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../config/env.dart';
import '../../config/theme.dart';
import '../../core/firebase/providers.dart';
import '../../core/models/momento_category.dart';
import '../../core/repositories/momento_repository.dart';
import '../../core/repositories/organisor_requests_repository.dart';
import '../../core/widgets/category_chip.dart';
import '../../core/widgets/momento_button.dart';
import '../../core/widgets/responsive_content.dart';

class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  MomentoCategory? _category;
  DateTime? _start;
  DateTime? _end;
  String? _locationLabel;
  XFile? _coverPhoto;
  bool _publishing = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await _pickDateTime(initial: _start ?? DateTime.now());
    if (picked != null) {
      setState(() {
        _start = picked;
        _end ??= picked.add(const Duration(hours: 2));
      });
    }
  }

  Future<void> _pickEndTime() async {
    final base = _start ?? DateTime.now();
    final picked = await _pickDateTime(
      initial: _end ?? base.add(const Duration(hours: 2)),
      first: base,
      last: base.add(Duration(days: Env.maxMomentoDurationDays)),
    );
    if (picked != null) setState(() => _end = picked);
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    DateTime? first,
    DateTime? last,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime.now(),
      lastDate: last ?? DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 88,
    );
    if (picked != null) setState(() => _coverPhoto = picked);
  }

  Future<void> _publish() async {
    if (_publishing) return;
    final user = ref.read(authStateChangesProvider).value;
    if (user == null) return;
    final used = ref.read(freemiumUsedProvider);
    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium && used >= Env.freemiumLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coming soon — paid Momentos launch later'),
        ),
      );
      return;
    }
    if (_title.text.trim().isEmpty ||
        _category == null ||
        _start == null ||
        _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title, category, and dates are required'),
        ),
      );
      return;
    }
    if (_locationLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a location for your Momento')),
      );
      return;
    }

    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    final go = GoRouter.of(context);
    try {
      final repo = ref.read(momentoRepositoryProvider);
      final userDoc = ref.read(currentUserDocProvider).value?.data();
      await repo.createMomento(
        organizerUid: user.uid,
        organizerName: (userDoc?['display_name'] as String?) ??
            user.displayName ??
            user.email ??
            'Organizer',
        organizerAvatarUrl:
            (userDoc?['avatar_url'] as String?) ?? user.photoURL ?? '',
        input: CreateMomentoInput(
          title: _title.text.trim(),
          description: _description.text.trim(),
          category: _category!,
          startDateTime: _start!,
          endDateTime: _end!,
          locationAddress: _locationLabel!,
          locationCity: 'Berlin',
          // TODO: real geocoding once Maps key lands.
          lat: 52.5200,
          lng: 13.4050,
          coverPhoto: _coverPhoto,
        ),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Momentō published')),
      );
      go.go('/discover');
    } on FreemiumExceeded {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Coming soon — paid Momentos launch later')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Publish failed: $e')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final used = ref.watch(freemiumUsedProvider);
    final progress =
        (used / Env.freemiumLimit).clamp(0.0, 1.0).toDouble();
    final isOrganisor = ref.watch(isOrganisorProvider);

    if (!isOrganisor) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(onClose: () => context.go('/discover')),
              const Expanded(child: _BecomeOrganisorPanel()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onClose: () => context.go('/discover')),
            Expanded(
              // Form fits comfortably at 560 — wider just spreads the
              // inputs and looks unanchored.
              child: ResponsiveContent(
                maxWidth: 560,
                padding: EdgeInsets.zero,
                child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                children: [
                  _Label('TITLE'),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      hintText: 'Give your Momento a name',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Label('CATEGORY'),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: MomentoCategory.values.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (_, i) {
                        final c = MomentoCategory.values[i];
                        return CategoryChip(
                          label: c.displayName,
                          selected: _category == c,
                          onTap: () => setState(() => _category = c),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Label('WHEN'),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _DateTimeTile(
                          icon: Icons.calendar_today_outlined,
                          label: 'Start',
                          value: _start,
                          onTap: _pickStartTime,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _DateTimeTile(
                          icon: Icons.event_busy_outlined,
                          label: 'End',
                          value: _end,
                          onTap: _pickEndTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Max duration: ${Env.maxMomentoDurationDays} days',
                    style: AppText.labelSmall
                        .copyWith(color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Label('WHERE'),
                  const SizedBox(height: AppSpacing.sm),
                  _LocationTile(
                    label: _locationLabel ?? 'Set location',
                    onTap: () => _showLocationStub(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Label('DESCRIPTION'),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _description,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: "Tell the community what's happening…",
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Label('PHOTOS'),
                  const SizedBox(height: AppSpacing.sm),
                  _PhotoUpload(
                    photo: _coverPhoto,
                    onTap: _pickPhoto,
                    onClear: () => setState(() => _coverPhoto = null),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
              ),
            ),
            _StickyPublish(
              used: used,
              progress: progress,
              busy: _publishing,
              onPublish: _publish,
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationStub() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (_) {
        final addresses = const [
          'Tiergarten — entrance Brandenburger Tor',
          '124 Creative District, Warehouse B',
          'Old Square',
          'Cellar Bar, Friedrichstraße 12',
          'Rooftop, Mitte',
        ];
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
                ...addresses.map((a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined,
                          color: AppColors.primary),
                      title: Text(a),
                      onTap: () {
                        setState(() => _locationLabel = a);
                        Navigator.pop(context);
                      },
                    )),
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
      },
    );
  }
}

class _BecomeOrganisorPanel extends ConsumerStatefulWidget {
  const _BecomeOrganisorPanel();

  @override
  ConsumerState<_BecomeOrganisorPanel> createState() =>
      _BecomeOrganisorPanelState();
}

class _BecomeOrganisorPanelState
    extends ConsumerState<_BecomeOrganisorPanel> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    // Three sub-states (matches the Profile role card):
    //   - no request   → CTA "Request to host"
    //   - pending      → "Application under review", no CTA
    //   - rejected     → reason + "Try again"
    // Once approved, role flips to organisor and CreateScreen renders the
    // form instead of this panel — so we don't render an approved branch.
    final myReq = ref.watch(myOrganisorRequestProvider).value;
    final isPending =
        myReq?.status == OrganisorRequestStatus.pending;
    final isRejected =
        myReq?.status == OrganisorRequestStatus.rejected;

    final title = isPending
        ? 'Application under review'
        : isRejected
            ? 'Application not approved'
            : 'Want to host?';
    final body = isPending
        ? "An admin will review and let you know. You'll see Create unlock here automatically once you're approved."
        : isRejected
            ? ((myReq?.decidedReason?.trim().isNotEmpty ?? false)
                ? 'Reason: ${myReq!.decidedReason}\n\nFeel free to try again with a stronger application.'
                : "We didn't approve this one. Feel free to try again.")
            : 'To create Momentos you need an organisor account. Send a request and an admin will review it.';
    final accent = isRejected ? AppColors.error : AppColors.primary;
    final iconData = isPending
        ? Icons.hourglass_empty_rounded
        : isRejected
            ? Icons.cancel_outlined
            : Icons.local_florist_outlined;

    // 560 keeps the green CTA from stretching ear-to-ear on desktop.
    return ResponsiveContent(
      maxWidth: 560,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1),
              ),
              alignment: Alignment.center,
              child: Icon(iconData, size: 44, color: accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                style: AppText.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.bodyMedium
                  .copyWith(color: AppColors.secondaryText, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!isPending)
              MomentoButton(
                label: _busy
                    ? 'Sending…'
                    : isRejected
                        ? 'Try again'
                        : 'Request to host',
                icon: Icons.send_outlined,
                variant: MomentoButtonVariant.primary,
                size: MomentoButtonSize.large,
                fullWidth: true,
                onPressed: _busy ? null : _submitRequest,
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isPending
                  ? "We're not far — keep an eye on this screen."
                  : 'You can stop hosting at any time from your Profile.',
              textAlign: TextAlign.center,
              style: AppText.labelSmall
                  .copyWith(color: AppColors.secondaryText),
            ),
          ],
        ),
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
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: AppColors.primaryText,
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              'Create a Momentō',
              textAlign: TextAlign.center,
              style: AppText.titleMedium,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.labelSmall.copyWith(
        color: AppColors.secondaryText,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM · h:mm a');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryText),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                value == null ? label : fmt.format(value!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyMedium.copyWith(
                  color: value == null
                      ? AppColors.secondaryText
                      : AppColors.primaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                size: 20, color: AppColors.primaryText),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppText.bodyMedium)),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.secondaryText),
          ],
        ),
      ),
    );
  }
}

class _PhotoUpload extends StatelessWidget {
  const _PhotoUpload({
    required this.photo,
    required this.onTap,
    required this.onClear,
  });

  final XFile? photo;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return GestureDetector(
        onTap: onTap,
        child: DottedBorder(
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined,
                    size: 32, color: AppColors.primaryText),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Upload your Momento cover photo',
                  style: AppText.bodySmall
                      .copyWith(color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: kIsWeb
                ? Image.network(photo!.path, fit: BoxFit.cover)
                : Image.file(File(photo!.path), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Material(
            color: Colors.black.withValues(alpha: 0.5),
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 18),
              onPressed: onClear,
            ),
          ),
        ),
      ],
    );
  }
}

class DottedBorder extends StatelessWidget {
  const DottedBorder({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadii.md),
    );
    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, 6, 4);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, double dashWidth, double dashSpace) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        dest.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + dashSpace;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(_) => false;
}

class _StickyPublish extends StatelessWidget {
  const _StickyPublish({
    required this.used,
    required this.progress,
    required this.busy,
    required this.onPublish,
  });

  final int used;
  final double progress;
  final bool busy;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final overQuota = used >= Env.freemiumLimit;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
        boxShadow: AppShadows.lg,
      ),
      // Background spans full viewport (docked-toolbar feel); inner content
      // capped at 560 to match the form column above it.
      child: ResponsiveContent(
        maxWidth: 560,
        padding: EdgeInsets.zero,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '$used of ${Env.freemiumLimit} free Momentos used',
                style: AppText.labelSmall
                    .copyWith(color: AppColors.secondaryText),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: AppText.labelSmall
                    .copyWith(color: AppColors.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
          const SizedBox(height: AppSpacing.md),
          MomentoButton(
            label: busy
                ? 'Publishing…'
                : overQuota
                    ? 'Pay & Publish — coming soon'
                    : 'Publish Momentō',
            variant: overQuota
                ? MomentoButtonVariant.primary
                : MomentoButtonVariant.outline,
            size: MomentoButtonSize.large,
            fullWidth: true,
            onPressed: busy ? null : onPublish,
          ),
        ],
      ),
      ),
    );
  }
}
