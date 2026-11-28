// lib/presentation/breathing/breathing_session_screen.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/music_route_scope.dart';
import '../../core/audio/sound_effect.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'breathing_complete_screen.dart';

/// Sesión de respiración guiada (F5). 100% visual: sin backend, sin
/// score, sin guardar la sesión.
class BreathingSessionScreen extends StatefulWidget {
  const BreathingSessionScreen({
    super.key,
    required this.minutes,
    required this.userName,
    this.onSessionCompleted,
  });

  final int minutes;
  final String userName;

  /// Gancho para el evento de Analytics 'breathing_session_completed'
  /// (único parámetro: duration_minutes, sin datos identificables).
  /// Esta pantalla NO llama a Firebase directamente — se conecta cuando
  /// Daniela defina dónde vive el servicio de Analytics.
  final VoidCallback? onSessionCompleted;

  @override
  State<BreathingSessionScreen> createState() => _BreathingSessionScreenState();
}

class _BreathingSessionScreenState extends State<BreathingSessionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  Timer? _timer;
  late int _remainingSeconds;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.minutes * 60;

    _controller = AnimationController(
      duration: const Duration(seconds: 9),
      vsync: this,
    )..repeat();

    // Cuatro segundos para inhalar, uno para sostener y cuatro para exhalar.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.55,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 4,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 1),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.55,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 4,
      ),
    ]).animate(_controller);

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), _handleTick);
  }

  void _handleTick(Timer timer) {
    if (_remainingSeconds <= 1) {
      timer.cancel();
      _controller.stop();
      setState(() => _remainingSeconds = 0);
      widget.onSessionCompleted?.call();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BreathingCompleteScreen(userName: widget.userName),
        ),
      );
      return;
    }
    setState(() => _remainingSeconds -= 1);
  }

  void _togglePause() {
    if (_isPaused) {
      // Reanuda el ciclo desde la fase y el punto en que quedó.
      _controller.repeat();
      _startTimer();
    } else {
      _timer?.cancel();
      _controller.stop();
    }
    setState(() => _isPaused = !_isPaused);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String get _remainingTimeLabel {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return 'Tiempo restante $minutes minutos $seconds segundos';
  }

  @override
  Widget build(BuildContext context) {
    return MusicRouteScope(
      track: MusicTrack.calma,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _ExitButton(onTap: () => Navigator.pop(context)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Un momento para usted',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading,
                      ),
                      const Spacer(),
                      ExcludeSemantics(
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _scale,
                            builder: (context, _) => CustomPaint(
                              size: const Size.square(224),
                              painter: _BreathingFlowerPainter(
                                openness:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? 0.8
                                    : (_scale.value - 0.55) / 0.45,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final instructionText = switch (_controller.value) {
                            _ when _isPaused => 'En pausa',
                            < 4 / 9 => 'Inhale suavemente',
                            < 5 / 9 => 'Sostenga un instante',
                            _ => 'Exhale despacio',
                          };
                          return Semantics(
                            liveRegion: true,
                            label: instructionText,
                            child: ExcludeSemantics(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  instructionText,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.greeting.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 28,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isPaused
                            ? 'Continúe cuando lo desee.'
                            : 'Respire con suavidad, a su ritmo.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: OutlinedButton(
                          onPressed: _togglePause,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(
                              color: AppColors.textPrimary,
                              width: 2,
                            ),
                            minimumSize: const Size(160, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(_isPaused ? 'Continuar' : 'Pausar'),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tiempo restante',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySecondary,
                      ),
                      Semantics(
                        liveRegion: false,
                        label: _remainingTimeLabel,
                        child: ExcludeSemantics(
                          child: Text(
                            _formattedTime,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.heading.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExitButton extends StatelessWidget {
  const _ExitButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Salir',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreathingFlowerPainter extends CustomPainter {
  const _BreathingFlowerPainter({required this.openness});

  final double openness;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final unit = size.shortestSide;
    final haloRadius = unit * (0.34 + 0.15 * openness);
    canvas.drawCircle(
      center,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12 + 0.10 * openness),
            AppColors.primaryLight.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
    );

    canvas.translate(center.dx, center.dy);
    final length = unit * (0.23 + 0.14 * openness);
    final width = unit * (0.075 + 0.03 * openness);
    final petal = Path()
      ..moveTo(0, 0)
      ..cubicTo(-width, -length * 0.38, -width, -length * 0.78, 0, -length)
      ..cubicTo(width, -length * 0.78, width, -length * 0.38, 0, 0)
      ..close();
    final petalPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primaryLight, AppColors.primary],
      ).createShader(Rect.fromLTRB(-width, -length, width, 0));

    for (var index = 0; index < 8; index++) {
      canvas.drawPath(petal, petalPaint);
      canvas.rotate(math.pi / 4);
    }

    canvas.drawCircle(
      Offset.zero,
      unit * 0.036,
      Paint()..color = AppColors.primaryLight,
    );
    canvas.drawCircle(
      Offset.zero,
      unit * 0.016,
      Paint()..color = AppColors.surface,
    );
  }

  @override
  bool shouldRepaint(_BreathingFlowerPainter oldDelegate) =>
      oldDelegate.openness != openness;
}
