import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/momento.dart';

/// Tap-an-organizer-card navigation. Originally pushed a dedicated
/// `OrganizerDetailScreen`; now routes to `/u/:id`, the canonical public
/// profile URL. The unified `ProfileScreen` (in `features/profile/`)
/// handles both self and other modes.
extension OrganizerNav on Momento {
  void pushOrganizerDetail(BuildContext context) {
    context.push('/u/$organizerId');
  }
}
