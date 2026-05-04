import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../core/firebase/providers.dart';
import '../../core/widgets/momento_button.dart';
import '../../core/widgets/momento_logo.dart';
import '../../core/widgets/responsive_content.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _busy = false;

  Future<void> _runAuth(Future<UserCredential> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
      if (!mounted) return;
      context.go('/discover');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code != 'cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Sign-in failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showEmailSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (_) => _EmailAuthSheet(
        onSubmit: (email, password, isSignUp) => _runAuth(() async {
          final repo = ref.read(authRepositoryProvider);
          return isSignUp
              ? repo.signUpWithEmail(email, password)
              : repo.signInWithEmail(email, password);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(authRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            maxWidth: 480,
            padding: EdgeInsets.zero,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 64, 40, 32),
                child: Column(
                  children: [
                    const MomentoLogo(fontSize: 28, letterSpacing: 7),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      "Find what's happening",
                      textAlign: TextAlign.center,
                      style: AppText.headlineMedium
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'around you, right now',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primaryText,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  border: Border.all(color: AppColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: const _AuthHeroPlaceholder(),
              ),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Get started', style: AppText.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Sign in to discover local Momentos',
                      style: AppText.bodyMedium
                          .copyWith(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    MomentoButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata_rounded,
                      size: MomentoButtonSize.large,
                      fullWidth: true,
                      onPressed:
                          _busy ? null : () => _runAuth(repo.signInWithGoogle),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MomentoButton(
                      label: 'Continue with email',
                      icon: Icons.mail_outline_rounded,
                      size: MomentoButtonSize.large,
                      fullWidth: true,
                      onPressed: _busy ? null : _showEmailSheet,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Text(
                        'By continuing, you agree to our Terms of Service',
                        textAlign: TextAlign.center,
                        style: AppText.labelSmall.copyWith(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _AuthHeroPlaceholder extends StatelessWidget {
  const _AuthHeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.20),
                AppColors.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Center(
          child: Icon(
            Icons.local_florist_outlined,
            size: 64,
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _EmailAuthSheet extends StatefulWidget {
  const _EmailAuthSheet({required this.onSubmit});
  final Future<void> Function(String email, String password, bool isSignUp)
      onSubmit;

  @override
  State<_EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends State<_EmailAuthSheet> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(_isSignUp ? 'Create account' : 'Sign in',
              style: AppText.titleLarge),
          const SizedBox(height: AppSpacing.md),
          // Sign in / Sign up segmented control — discoverable toggle.
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.full),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _SegmentTab(
                  label: 'Sign in',
                  active: !_isSignUp,
                  onTap: () => setState(() => _isSignUp = false),
                ),
                _SegmentTab(
                  label: 'Sign up',
                  active: _isSignUp,
                  onTap: () => setState(() => _isSignUp = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _email,
            decoration: const InputDecoration(hintText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _pw,
            decoration: const InputDecoration(hintText: 'Password'),
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          MomentoButton(
            label: _isSignUp ? 'Sign up' : 'Sign in',
            variant: MomentoButtonVariant.primary,
            size: MomentoButtonSize.large,
            fullWidth: true,
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await widget.onSubmit(
                          _email.text.trim(), _pw.text, _isSignUp);
                      if (mounted) Navigator.pop(context);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.background : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.full),
            boxShadow: active ? AppShadows.sm : null,
          ),
          child: Text(
            label,
            style: AppText.labelMedium.copyWith(
              color: active ? AppColors.primaryText : AppColors.secondaryText,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
