import 'package:flutter/widgets.dart';

import '../../core/models/momento.dart';
import '../../core/widgets/slide_up_route.dart';
import '../profile/profile_screen.dart';

/// Tap-an-organizer-card navigation. Pushes the unified `ProfileScreen`
/// (other-mode) via `Navigator.push` so it sits on top of any slide-up
/// modal that's already open (e.g. a Momento detail). Mixing
/// `context.push` here with the slide-up routes confuses go_router's
/// page list, so we keep the in-app flow on the vanilla Navigator and
/// reserve the `/u/:id` go_router route for incoming share links.
extension OrganizerNav on Momento {
  void pushOrganizerDetail(BuildContext context) {
    Navigator.of(context).push(
      slideUpRoute(ProfileScreen(userId: organizerId)),
    );
  }
}
