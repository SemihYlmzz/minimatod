import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/settings/app_settings_controller.dart';
import 'intro_animation.dart';

/// Shows onboarding, then reveals the app with a premium circular "portal"
/// transition expanding from the Start button.
///
/// Once Start is tapped it's remembered (via [AppSettingsController]) and never
/// shown again — unless [forceShow] is true, which replays it every launch
/// (handy while designing; see the flag in `main.dart`).
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.settings,
    required this.child,
    this.forceShow = false,
  });

  final AppSettingsController settings;
  final Widget child;
  final bool forceShow;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  late final bool _show =
      widget.forceShow || !widget.settings.hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    if (!_show) _t.value = 1; // straight to the app
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _start() {
    if (_t.isAnimating || _t.isCompleted) return;
    widget.settings.markOnboardingSeen(); // remember even in force mode
    _t.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final v = _t.value;
        if (v == 0) return IntroAnimation(onComplete: _start);
        if (v >= 1) return widget.child;

        // Onboarding eases back + dims; the home page opens through a growing
        // circle from the Start button.
        final reveal = Curves.easeInOutCubic.transform(v);
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 1 - Curves.easeIn.transform(v),
              child: Transform.scale(
                scale: 1 - 0.06 * v,
                child: IntroAnimation(onComplete: _start),
              ),
            ),
            ClipPath(
              clipper: _PortalClipper(reveal),
              child: Transform.scale(
                scale: 1.04 - 0.04 * reveal, // settle in
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PortalClipper extends CustomClipper<Path> {
  _PortalClipper(this.progress);
  final double progress;

  @override
  Path getClip(Size size) {
    final origin = Offset(size.width / 2, size.height * 0.86); // Start button
    final maxR = math.sqrt(
      math.max(origin.dx, size.width - origin.dx) *
              math.max(origin.dx, size.width - origin.dx) +
          math.max(origin.dy, size.height - origin.dy) *
              math.max(origin.dy, size.height - origin.dy),
    );
    return Path()
      ..addOval(Rect.fromCircle(center: origin, radius: maxR * progress));
  }

  @override
  bool shouldReclip(_PortalClipper old) => old.progress != progress;
}
