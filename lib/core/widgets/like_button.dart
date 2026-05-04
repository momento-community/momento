import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../../config/theme.dart';
import '../firebase/providers.dart';

/// Floating heart used as a card overlay (top-right of the cover image) and
/// inline elsewhere. State is derived from `momento.likedBy` so the heart
/// flips the instant the underlying Momento doc updates.
///
/// Optimistic-update pattern: on tap we set local `_pending` so the icon
/// fills immediately, even before Firestore round-trips. The next stream
/// emission overwrites it with the authoritative value.
class LikeButton extends ConsumerStatefulWidget {
  const LikeButton({
    super.key,
    required this.momentoId,
    required this.likedBy,
    this.size = LikeButtonSize.regular,
  });

  final String momentoId;
  final List<String> likedBy;
  final LikeButtonSize size;

  @override
  ConsumerState<LikeButton> createState() => _LikeButtonState();
}

enum LikeButtonSize { compact, regular }

class _LikeButtonState extends ConsumerState<LikeButton> {
  bool? _pending; // local optimistic value until the doc stream catches up.
  String? _pendingForUid;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateChangesProvider).value;
    final canonical = me != null && widget.likedBy.contains(me.uid);
    // Drop the optimistic value once the canonical state agrees with it
    // (or once the user changed).
    if (_pending != null &&
        (_pendingForUid != me?.uid || _pending == canonical)) {
      _pending = null;
      _pendingForUid = null;
    }
    final liked = _pending ?? canonical;

    final iconSize = widget.size == LikeButtonSize.compact ? 16.0 : 20.0;
    final pad = widget.size == LikeButtonSize.compact
        ? const EdgeInsets.all(6)
        : const EdgeInsets.all(8);

    return Material(
      color: AppColors.background.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: me == null ? null : () => _toggle(me.uid, liked),
        child: Padding(
          padding: pad,
          child: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: iconSize,
            color: liked ? AppColors.error : AppColors.primaryText,
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(String uid, bool currentlyLiked) async {
    if (Env.useMockData) return; // no-op in offline UI mode
    setState(() {
      _pending = !currentlyLiked;
      _pendingForUid = uid;
    });
    try {
      await ref
          .read(momentoRepositoryProvider)
          .toggleLike(widget.momentoId, uid);
    } catch (_) {
      // Revert optimistic flip on failure.
      if (mounted) {
        setState(() {
          _pending = null;
          _pendingForUid = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like — try again.')),
        );
      }
    }
  }
}
