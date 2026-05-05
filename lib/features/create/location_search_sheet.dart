import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../core/firebase/providers.dart';
import '../../core/services/place_search_service.dart';

/// Bottom-sheet location picker. Type-ahead → Google Places autocomplete
/// predictions → tap → resolve to lat/lng → pop with a `PickedPlace`.
///
/// Used by Create + Momento detail's `_editLocation`.
Future<PickedPlace?> showLocationSearchSheet(BuildContext context) {
  return showModalBottomSheet<PickedPlace>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
    ),
    builder: (_) => const _LocationSearchBody(),
  );
}

class _LocationSearchBody extends ConsumerStatefulWidget {
  const _LocationSearchBody();

  @override
  ConsumerState<_LocationSearchBody> createState() =>
      _LocationSearchBodyState();
}

class _LocationSearchBodyState extends ConsumerState<_LocationSearchBody> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  // While we're resolving lat/lng for a tapped prediction. Disables the
  // list so the user can't tap another row mid-flight.
  bool _resolving = false;
  String? _error;
  List<PlacePrediction> _predictions = const [];
  // Tracks which query a pending request was issued for. Out-of-order
  // responses get dropped so a slow earlier request can't overwrite a
  // fresh one.
  String _activeQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _predictions = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    // 300ms balances quick feedback against hammering the autocomplete
    // endpoint (it's metered + costs money per session).
    _debounce =
        Timer(const Duration(milliseconds: 300), () => _search(trimmed));
  }

  Future<void> _search(String query) async {
    _activeQuery = query;
    try {
      final results =
          await ref.read(placeSearchServiceProvider).autocomplete(query);
      if (!mounted) return;
      // Drop the response if a newer query is already in flight.
      if (_activeQuery != query) return;
      setState(() {
        _predictions = results;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_activeQuery != query) return;
      setState(() {
        _predictions = const [];
        _loading = false;
        _error = 'Search failed. Check your connection and try again.';
      });
    }
  }

  Future<void> _pick(PlacePrediction p) async {
    setState(() {
      _resolving = true;
      _error = null;
    });
    final picked =
        await ref.read(placeSearchServiceProvider).resolve(p.placeId);
    if (!mounted) return;
    if (picked == null) {
      setState(() {
        _resolving = false;
        _error = "Couldn't load that place. Try another.";
      });
      return;
    }
    Navigator.pop(context, picked);
  }

  @override
  Widget build(BuildContext context) {
    // Push the sheet up when the keyboard appears so the input + a few
    // suggestions stay visible above the fold.
    final viewInsetBottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsetBottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                  ),
                ),
                Text('Where is it?', style: AppText.titleMedium),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  enabled: !_resolving,
                  decoration: InputDecoration(
                    hintText: 'Search a place, address, landmark…',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.secondaryText),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            color: AppColors.secondaryText,
                            onPressed: _resolving
                                ? null
                                : () {
                                    _controller.clear();
                                    _onChanged('');
                                  },
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(_error!,
            style: AppText.bodySmall.copyWith(color: AppColors.error)),
      );
    }
    if (_loading || _resolving) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
      );
    }
    if (_predictions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          _controller.text.isEmpty ? 'Type to search.' : 'No matches.',
          style:
              AppText.labelSmall.copyWith(color: AppColors.secondaryText),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _predictions.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (_, i) {
        final p = _predictions[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.location_on_outlined,
              color: AppColors.primary),
          title: Text(p.label,
              maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => _pick(p),
        );
      },
    );
  }
}
