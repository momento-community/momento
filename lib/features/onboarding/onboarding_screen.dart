import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/widgets/momento_button.dart';
import '../../core/widgets/momento_logo.dart';
import '../../core/widgets/responsive_content.dart';

class _Slide {
  const _Slide({
    required this.tagline,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String tagline;
  final String title;
  final String subtitle;
  final IconData icon;
}

const _slides = [
  _Slide(
    tagline: 'AROUND YOU',
    title: 'Discover Momentos near you',
    subtitle:
        "Find temporary, curated events happening in your neighbourhood right now.",
    icon: Icons.explore_outlined,
  ),
  _Slide(
    tagline: 'WHEN IT SUITS YOU',
    title: 'Filter by time, place & vibe',
    subtitle:
        'Pick the moment, set a radius, and pull back only what fits your evening.',
    icon: Icons.tune_rounded,
  ),
  _Slide(
    tagline: 'YOUR TURN',
    title: 'Create your own Momentos',
    subtitle:
        'Host a pop-up, a session, a market — your first five Momentos are free.',
    icon: Icons.add_circle_outline_rounded,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  void _next() {
    if (_index == _slides.length - 1) {
      context.go('/auth');
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveContent(
          maxWidth: 480,
          padding: EdgeInsets.zero,
          child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      MomentoLogo(),
                      OBadge(size: 44),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 16, 40, 32),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (i) {
                          final active = i == _index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.divider,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.full),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      MomentoButton(
                        label: _index == _slides.length - 1
                            ? 'Get started'
                            : 'Next',
                        variant: MomentoButtonVariant.primary,
                        size: MomentoButtonSize.large,
                        fullWidth: true,
                        onPressed: _next,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      MomentoButton(
                        label: 'Skip',
                        variant: MomentoButtonVariant.ghost,
                        fullWidth: true,
                        onPressed: () => context.go('/auth'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.divider),
            ),
            alignment: Alignment.center,
            child: Icon(slide.icon, size: 72, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            slide.tagline,
            style: AppText.labelSmall.copyWith(
              color: AppColors.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppText.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: AppText.bodyMedium
                .copyWith(color: AppColors.secondaryText, height: 1.6),
          ),
        ],
      ),
    );
  }
}
