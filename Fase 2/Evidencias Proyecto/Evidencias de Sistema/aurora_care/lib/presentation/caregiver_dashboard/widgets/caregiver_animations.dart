import 'dart:async';

import 'package:flutter/material.dart';

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 450),
    this.offsetY = 18,
  });

  final Widget child;
  final int index;
  final Duration duration;
  final double offsetY;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 70 * widget.index);
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;

    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offsetY * (1 - _curve.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class GentlePulse extends StatefulWidget {
  const GentlePulse({super.key, required this.child, this.maxScale = 1.08});

  final Widget child;
  final double maxScale;

  @override
  State<GentlePulse> createState() => _GentlePulseState();
}

class _GentlePulseState extends State<GentlePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;

    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: widget.maxScale).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

class CountUpText extends StatelessWidget {
  const CountUpText({super.key, required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return Text('$value', style: style);

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => Text('$current', style: style),
    );
  }
}

class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + 80 * index),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: Opacity(
          opacity: value.clamp(0.0, 1.0).toDouble(),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

PageRouteBuilder<T> caregiverPageRoute<T>(
  Widget screen, {
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (_reduceMotion(context)) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
