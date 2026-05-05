import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/firebase/providers.dart';
import 'momento_detail_screen.dart';

/// Route wrapper for `/momento/:id`. Watches the live doc, hands it to
/// [MomentoDetailScreen]. Renders loading + not-found states so the deep
/// link is robust to bad ids and slow first-paint.
class MomentoDetailRoute extends ConsumerWidget {
  const MomentoDetailRoute({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(momentoByIdProvider(id));
    return async.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ),
      error: (e, _) => _NotFound(message: 'Could not load this Momento.\n$e'),
      data: (m) {
        if (m == null) {
          return const _NotFound(
              message: 'This Momento has been removed or is no longer active.');
        }
        return MomentoDetailScreen(momento: m);
      },
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.primaryText),
          onPressed: () => context.go('/discover'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 56, color: AppColors.secondaryText),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.bodyMedium
                    .copyWith(color: AppColors.secondaryText, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => context.go('/discover'),
                child: Text(
                  'Back to Discover',
                  style:
                      AppText.labelLarge.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
