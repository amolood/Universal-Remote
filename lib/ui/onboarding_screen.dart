import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../atv/atv_controller.dart';
import '../i18n/strings.dart';
import 'theme.dart';
import 'widgets/aurora_background.dart';
import 'widgets/glass.dart';

/// First-run intro: a few glass cards explaining discovery, pairing, and voice,
/// plus a language picker. Completes into the normal flow.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  List<_Slide> _slides(S s) => [
        _Slide(
          icon: Icons.wifi_tethering_rounded,
          title: s.obDiscoverTitle,
          body: s.obDiscoverBody,
          color: AppTheme.accent,
        ),
        _Slide(
          icon: Icons.link_rounded,
          title: s.obPairTitle,
          body: s.obPairBody,
          color: AppTheme.accent2,
        ),
        _Slide(
          icon: Icons.mic_rounded,
          title: s.obControlTitle,
          body: s.obControlBody,
          color: AppTheme.accentPink,
        ),
      ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(AtvController c) {
    Haptics.confirm();
    c.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AtvController>();
    final s = S.of(context);
    final slides = _slides(s);
    final isLast = _page == slides.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Language toggle (top)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _LangToggle(c: c),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (i) {
                    Haptics.select();
                    setState(() => _page = i);
                  },
                  itemBuilder: (_, i) => _SlideView(slide: slides[i]),
                ),
              ),
              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: active ? AppTheme.accentGradient : null,
                      color: active ? null : AppTheme.glassStroke,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: GradientButton(
                  label: isLast ? s.getStarted : s.next,
                  icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  onTap: () {
                    if (isLast) {
                      _finish(c);
                    } else {
                      Haptics.tap();
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                ),
              ),
              if (!isLast)
                TextButton(
                  onPressed: () => _finish(c),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.textMid),
                  child: Text(s.skip),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [slide.color, slide.color.withValues(alpha: 0.6)],
              ),
              boxShadow: AppTheme.glow(slide.color, strength: 0.5),
            ),
            child: Icon(slide.icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 36),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTheme.textHi,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textMid,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LangToggle extends StatelessWidget {
  final AtvController c;
  const _LangToggle({required this.c});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: AppTheme.rXl,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AppLang.values.map((l) {
          final active = c.lang == l;
          return GestureDetector(
            onTap: () {
              Haptics.select();
              c.setLang(l);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.rXl),
                gradient: active ? AppTheme.accentGradient : null,
              ),
              child: Text(
                l.nativeName,
                style: TextStyle(
                  color: active ? Colors.white : AppTheme.textMid,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
