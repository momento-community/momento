import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';
import '../firebase/providers.dart';
import 'momento_button.dart';

/// Toggle button that swaps between Follow / Following based on the current
/// user's relationship to [organizerId]. Hidden if the viewer is the
/// organizer themselves (you can't follow yourself).
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({
    super.key,
    required this.organizerId,
    this.size = MomentoButtonSize.small,
  });

  final String organizerId;
  final MomentoButtonSize size;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateChangesProvider).value;
    if (me == null || me.uid == widget.organizerId) {
      return const SizedBox.shrink();
    }
    final following = ref.watch(isFollowingProvider(widget.organizerId)).value
        ?? false;
    return MomentoButton(
      label: _busy
          ? '…'
          : following
              ? 'Following'
              : 'Follow',
      icon: following ? Icons.check_rounded : Icons.add_rounded,
      variant: following
          ? MomentoButtonVariant.outline
          : MomentoButtonVariant.primary,
      size: widget.size,
      onPressed: _busy ? null : () => _toggle(me.uid, following),
    );
  }

  Future<void> _toggle(String myUid, bool following) async {
    if (Env.useMockData) return;
    setState(() => _busy = true);
    try {
      await ref.read(followRepositoryProvider).toggle(
            followerId: myUid,
            followingId: widget.organizerId,
            currentlyFollowing: following,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Follow failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
