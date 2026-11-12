import 'package:flutter/material.dart';

import 'package:chronosync_calender/core/theme/app_theme.dart';

/// Brand splash shown on launch. It fades in, holds briefly, then cross-fades into [child].
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.child,
    this.holdDuration = const Duration(milliseconds: 1400),
  });

  final Widget child;

  /// How long the splash stays on screen before the app appears.
  final Duration holdDuration;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future<void>.delayed(widget.holdDuration, () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _done
          ? KeyedSubtree(key: const ValueKey('app'), child: widget.child)
          : _SplashView(key: const ValueKey('splash'), animation: _controller),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.calendar_month, size: 52, color: cs.onPrimary),
                ),
                const SizedBox(height: AppSpace.xl),
                Text(
                  'ChronoSync',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
