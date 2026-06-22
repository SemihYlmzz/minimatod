import 'package:flutter/material.dart';

import '../../../core/brand/logo_painter.dart';

/// A single, minimalist onboarding page: the logo, a fading tagline, and a
/// Start button. Tapping Start hands off to [onComplete]; the premium
/// transition to the home page is handled by the parent (see OnboardingGate).
class IntroAnimation extends StatefulWidget {
  const IntroAnimation({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  State<IntroAnimation> createState() => _IntroAnimationState();
}

class _IntroAnimationState extends State<IntroAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _fade(double begin, double end) => CurvedAnimation(
        parent: _c,
        curve: Interval(begin, end, curve: Curves.easeOut),
      );

  Widget _rise(Animation<double> a, Widget child) => FadeTransition(
        opacity: a,
        child: AnimatedBuilder(
          animation: a,
          builder: (_, c) =>
              Transform.translate(offset: Offset(0, (1 - a.value) * 16), child: c),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 5),
              _rise(
                _fade(0.0, 0.55),
                ScaleTransition(
                  scale: Tween(begin: 0.9, end: 1.0).animate(_fade(0.0, 0.6)),
                  child: MinimatodLogo(size: 104, markColor: cs.onSurface),
                ),
              ),
              const SizedBox(height: 28),
              _rise(
                _fade(0.3, 0.85),
                Text(
                  'Control your chaos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.4,
                    color: cs.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const Spacer(flex: 6),
              _rise(
                _fade(0.55, 1.0),
                // Cap the width so the button doesn't stretch edge-to-edge on
                // tablets / desktop / web; it stays full-width on phones.
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: widget.onComplete,
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Start',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
