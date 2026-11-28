import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_effect.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/accessibility_providers.dart';
import '../../../../core/providers/sound_providers.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../domain/usecases/evaluate_phone_swipe.dart';
import '../../shared/game_definition.dart';
import 'deslizar_imagenes_controller.dart';

class PhoneSwipeScreen extends ConsumerStatefulWidget {
  const PhoneSwipeScreen({super.key, required this.run});
  final GameRun run;
  @override
  ConsumerState<PhoneSwipeScreen> createState() => _PhoneSwipeScreenState();
}

class _PhoneSwipeScreenState extends ConsumerState<PhoneSwipeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _completionShown = false;

  /// Aciertos consecutivos (deslizamientos logrados), para
  /// SoundEffect.acierto(_racha). Se reinicia a 0 en cada deslizamiento
  /// fallido (silencioso: nunca error_suave en Praxias) y empieza en 0
  /// al abrir la partida.
  int _racha = 0;

  // Transición al lograr un cambio: la imagen actual sale y la siguiente
  // entra desde el punto donde quedó el dedo. Es una animación única (no se
  // repite), así que la pantalla vuelve a quedar en reposo sola.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  int _fromImage = 0;
  double _startDx = 0;
  int _sign = -1;
  static const _names = ['El jardín', 'Las montañas', 'La noche'];
  /// Todos los mensajes posibles: el espacio del mensaje se reserva con el más
  /// largo para que la imagen no se mueva cuando el texto cambia.
  static final List<String> _allMessages = [
    'Su práctica se conserva. Continúe cuando quiera.',
    'Ya puede soltar el dedo.',
    'Completó los cuatro recorridos.',
    'Muy bien. Ahora deslice hacia la derecha para volver.',
    'Puede recorrer un poco más de la imagen antes de levantar el dedo.',
    'Para deslizar, mueva el dedo sobre la imagen antes de levantarlo.',
    'Puede hacerlo despacio. Mantenga el dedo apoyado mientras se mueve.',
    for (final side in ['la izquierda', 'la derecha']) ...[
      'Muy bien. Siga deslizando hacia $side.',
      'Pruebe mover el dedo hacia $side.',
      'Pruebe un movimiento hacia $side, de un lado al otro de la imagen.',
      'Siga moviendo el dedo hacia $side.',
    ],
  ];
  PhoneSwipeController get _controller =>
      ref.read(phoneSwipeProvider(widget.run.nivel).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _slide.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller.pause();
  }

  @override
  void didChangeMetrics() => _controller.cancel();

  void _finish() {
    final metrics = _controller.finish();
    if (metrics != null) widget.run.finish(metrics);
  }

  Future<void> _completed() async {
    if (!mounted || _completionShown) return;
    _completionShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.primaryDark.withValues(alpha: .24),
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        scrollable: true,
        title: Text('Práctica completada', style: AppTextStyles.heading),
        content: Text(
          'Recorrió las imágenes y volvió a la primera. Puede consultar cómo fue su práctica.',
          style: AppTextStyles.body,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (mounted) _finish();
              },
              child: const Text('Ver mi resumen'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _help() async {
    final direction = ref.read(phoneSwipeProvider(widget.run.nivel)).direction;
    _controller.pause();
    final useButton = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.primaryDark.withValues(alpha: .24),
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        scrollable: true,
        title: Text('Cómo deslizar', style: AppTextStyles.heading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Apoye un dedo sobre la imagen. Sin levantarlo, muévalo hacia ${direction == SwipeDirection.left ? 'la izquierda' : 'la derecha'}. Después levántelo.',
              textAlign: TextAlign.justify,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            _SwipeDemo(direction: direction),
            const SizedBox(height: 12),
            Text(
              'Puede hacerlo despacio y repetirlo. Si lo prefiere, también puede cambiar la imagen con un botón de apoyo.',
              textAlign: TextAlign.justify,
              style: AppTextStyles.bodySecondary,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver a practicar'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cambiar con un botón'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      _controller.resume();
      if (useButton == true) _controller.changeWithButton();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = phoneSwipeProvider(widget.run.nivel);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (previous != null && next.imageIndex != previous.imageIndex) {
        _fromImage = previous.imageIndex;
        _startDx = previous.dragDx;
        _sign = next.imageIndex > previous.imageIndex ? -1 : 1;
        if (MediaQuery.disableAnimationsOf(context)) {
          _slide.value = 1;
        } else {
          _slide.forward(from: 0);
        }
      }
      if (next.completedActions > (previous?.completedActions ?? 0)) {
        ref.read(exerciseVibrationProvider)();
      }
      if (next.completed && previous?.completed != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _completed());
      }
      // Deslizamiento logrado: acierto con racha, en todos (incluido
      // el último). failuresOnStep sube solo con un intento real
      // (short/wrongDirection/vertical) — nunca con "tap" (que no es
      // un intento, se ignora) — y ese intento fallido queda
      // silencioso, solo reinicia la racha.
      if (next.completedActions > (previous?.completedActions ?? 0)) {
        _racha++;
        if (ref.read(soundsEnabledProvider)) {
          unawaited(
            ref.read(soundServiceProvider).play(SoundEffect.acierto(_racha)),
          );
        }
      } else if (next.failuresOnStep > (previous?.failuresOnStep ?? 0)) {
        _racha = 0;
      }
    });
    final left = state.direction == SwipeDirection.left;
    final directionText = left ? 'la izquierda' : 'la derecha';
    final feedback = switch (state.feedback) {
      SwipeOutcome.achieved =>
        state.completed
            ? 'Completó los cuatro recorridos.'
            : state.index == 2
            ? 'Muy bien. Ahora deslice hacia la derecha para volver.'
            : 'Muy bien. Siga deslizando hacia $directionText.',
      SwipeOutcome.short =>
        'Puede recorrer un poco más de la imagen antes de levantar el dedo.',
      SwipeOutcome.wrongDirection =>
        'Pruebe mover el dedo hacia $directionText.',
      SwipeOutcome.vertical =>
        'Pruebe un movimiento hacia $directionText, de un lado al otro de la imagen.',
      SwipeOutcome.tap =>
        'Para deslizar, mueva el dedo sobre la imagen antes de levantarlo.',
      SwipeOutcome.ready =>
        'Puede hacerlo despacio. Mantenga el dedo apoyado mientras se mueve.',
    };
    final message = state.paused
        ? 'Su práctica se conserva. Continúe cuando quiera.'
        : state.dragging
        ? (state.readyToRelease
              ? 'Ya puede soltar el dedo.'
              : 'Siga moviendo el dedo hacia $directionText.')
        : feedback;
    final showCheck =
        state.readyToRelease ||
        (!state.dragging && state.feedback == SwipeOutcome.achieved);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Practicar con mi teléfono', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 8),
          Text(
            'Recorrido ${state.index + 1} de ${PhoneSwipeState.directions.length}',
            style: AppTextStyles.greeting,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: state.completedActions / PhoneSwipeState.directions.length,
            color: AppColors.primary,
            backgroundColor: AppColors.primaryLight,
            semanticsLabel:
                'Cambios de imagen completados: ${state.completedActions} de ${PhoneSwipeState.directions.length}',
          ),
          const SizedBox(height: 20),
          _StableHeight(
            candidates: const [
              'Deslice hacia la izquierda',
              'Deslice hacia la derecha',
            ],
            style: AppTextStyles.heading,
            reservedWidth: 44, // ícono de 32 + separación de 12
            minHeight: 32,
            child: Row(
              children: [
                Icon(
                  left ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Deslice hacia $directionText',
                    style: AppTextStyles.heading,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _StableHeight(
            candidates: _allMessages,
            style: AppTextStyles.body,
            reservedWidth: 32, // ícono de 24 + separación de 8
            minHeight: 24,
            child: Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    showCheck
                        ? Icons.check_circle_outline_rounded
                        : Icons.swipe_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(message, style: AppTextStyles.body)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _StableHeight(
                    candidates: [
                      for (var i = 0; i < _names.length; i++)
                        'Imagen ${i + 1} de 3 · ${_names[i]}',
                    ],
                    style: AppTextStyles.cardTitle,
                    reservedWidth: 62, // tres puntos de 12 + márgenes + 8
                    child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Imagen ${state.imageIndex + 1} de 3 · ${_names[state.imageIndex]}',
                          style: AppTextStyles.cardTitle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < 3; i++)
                              Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.only(left: 6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == state.imageIndex
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                AspectRatio(
                  aspectRatio: 1.2,
                  child: LayoutBuilder(
                    builder: (context, box) => Semantics(
                      label:
                          '${_names[state.imageIndex]}. Deslice hacia $directionText.',
                      image: true,
                      customSemanticsActions: state.blocked
                          ? null
                          : {
                              const CustomSemanticsAction(
                                label: 'Cambiar de imagen con apoyo',
                              ): _controller.changeWithButton,
                            },
                      child: RawGestureDetector(
                        excludeFromSemantics: true,
                        gestures: {
                          EagerGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                EagerGestureRecognizer
                              >(() => EagerGestureRecognizer(), (_) {}),
                        },
                        child: Listener(
                          key: const ValueKey('phone_swipe_board'),
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (e) => _controller.down(
                            e.pointer,
                            e.localPosition.dx,
                            e.localPosition.dy,
                            box.maxWidth,
                          ),
                          onPointerMove: (e) => _controller.move(
                            e.pointer,
                            e.localPosition.dx,
                            e.localPosition.dy,
                          ),
                          onPointerUp: (e) {
                            _controller.move(
                              e.pointer,
                              e.localPosition.dx,
                              e.localPosition.dy,
                            );
                            _controller.up(e.pointer);
                          },
                          onPointerCancel: (e) => _controller.cancel(e.pointer),
                          child: ClipRect(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ColoredBox(color: AppColors.primaryLight),
                                AnimatedBuilder(
                                  animation: _slide,
                                  builder: (context, _) {
                                    final w = box.maxWidth;
                                    final moving = _slide.isAnimating;
                                    final neighbor =
                                        state.imageIndex +
                                        (state.dragDx < 0 ? 1 : -1);
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (moving) ...[
                                          () {
                                            final t = Curves.easeOut.transform(
                                              _slide.value,
                                            );
                                            final outX =
                                                _startDx +
                                                (_sign * w - _startDx) * t;
                                            return Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                _page(_fromImage, outX),
                                                _page(
                                                  state.imageIndex,
                                                  outX - _sign * w,
                                                ),
                                              ],
                                            );
                                          }(),
                                        ] else ...[
                                          // La imagen vecina acompaña al dedo,
                                          // como en la galería del teléfono.
                                          if (state.dragging &&
                                              neighbor >= 0 &&
                                              neighbor <= 2)
                                            _page(
                                              neighbor,
                                              state.dragDx +
                                                  (state.dragDx < 0 ? w : -w),
                                            ),
                                          AnimatedContainer(
                                            duration:
                                                state.dragging ||
                                                    MediaQuery.disableAnimationsOf(
                                                      context,
                                                    )
                                                ? Duration.zero
                                                : const Duration(
                                                    milliseconds: 220,
                                                  ),
                                            transform: Matrix4.translationValues(
                                              state.dragDx.clamp(-w, w),
                                              0,
                                              0,
                                            ),
                                            child: CustomPaint(
                                              painter: _GalleryPainter(
                                                state.imageIndex,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (!moving &&
                                            !state.blocked &&
                                            !state.dragging)
                                          _DirectionHint(
                                            key: ValueKey(
                                              'hint_${state.index}_${state.imageIndex}',
                                            ),
                                            left: left,
                                          ),
                                        if (!state.blocked)
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            child: ExcludeSemantics(
                                              child: LinearProgressIndicator(
                                                value: state.dragProgress,
                                                minHeight: 12,
                                                color: state.readyToRelease
                                                    ? AppColors.success
                                                    : AppColors.primary,
                                                backgroundColor:
                                                    AppColors.border,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                if (state.paused)
                                  ColoredBox(
                                    color: AppColors.surface,
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          'Práctica en pausa',
                                          style: AppTextStyles.heading,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.offerAssist && !state.blocked) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey('phone_swipe_assist'),
              onPressed: _controller.changeWithButton,
              child: const Text('Cambiar la imagen con un botón'),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: state.finished
                ? null
                : state.paused
                ? _controller.resume
                : _controller.pause,
            child: Text(
              state.paused ? 'Continuar práctica' : 'Pausar práctica',
            ),
          ),
          TextButton.icon(
            onPressed: state.blocked ? null : _help,
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text('Ver cómo hacerlo'),
          ),
        ],
      ),
    );
  }

  Widget _page(int index, double x) => Transform.translate(
    offset: Offset(x, 0),
    child: CustomPaint(
      painter: _GalleryPainter(index),
      child: const SizedBox.expand(),
    ),
  );
}

/// Reserva el alto del texto más largo entre varias opciones, para que el
/// contenido de abajo (la imagen) no se mueva cuando el texto cambia de
/// cantidad de líneas. Mide con el mismo estilo efectivo que dibuja el Text.
class _StableHeight extends StatefulWidget {
  const _StableHeight({
    required this.candidates,
    required this.style,
    required this.reservedWidth,
    required this.child,
    this.minHeight = 0,
  });

  /// Todos los textos que pueden aparecer en este lugar.
  final List<String> candidates;
  final TextStyle style;

  /// Ancho que ocupa lo que acompaña al texto (ícono, separación, puntos).
  final double reservedWidth;
  final double minHeight;
  final Widget child;

  @override
  State<_StableHeight> createState() => _StableHeightState();
}

class _StableHeightState extends State<_StableHeight> {
  String? _cacheKey;
  double _cacheHeight = 0;

  double _tallest(BuildContext context, double maxWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final key =
        '$maxWidth|${scaler.scale(18)}|${style.height}|${style.fontSize}';
    if (key == _cacheKey) return _cacheHeight;
    var tallest = widget.minHeight;
    for (final text in widget.candidates) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: math.max(0, maxWidth - widget.reservedWidth));
      tallest = math.max(tallest, painter.height);
      painter.dispose();
    }
    _cacheKey = key;
    return _cacheHeight = tallest;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: _tallest(context, box.maxWidth)),
        child: widget.child,
      ),
    );
  }
}

/// Flecha que se desliza una vez hacia el lado pedido al empezar cada acción.
class _DirectionHint extends StatelessWidget {
  const _DirectionHint({super.key, required this.left});
  final bool left;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Align(
          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: still ? Duration.zero : const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, v, child) => Transform.translate(
                offset: Offset((left ? 1 : -1) * 28 * (1 - v), 0),
                child: child,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface.withValues(alpha: .85),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    left
                        ? Icons.arrow_back_rounded
                        : Icons.arrow_forward_rounded,
                    size: 40,
                    color: AppColors.primary,
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

class _SwipeDemo extends StatelessWidget {
  const _SwipeDemo({required this.direction});
  final SwipeDirection direction;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    height: 80,
    child: LayoutBuilder(
      builder: (context, box) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 1500),
        builder: (_, progress, _) => Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: Icon(
                  direction == SwipeDirection.left
                      ? Icons.west_rounded
                      : Icons.east_rounded,
                  size: 64,
                  color: AppColors.border,
                ),
              ),
            ),
            Positioned(
              left:
                  box.maxWidth * .5 -
                  20 +
                  (direction == SwipeDirection.left ? -1 : 1) *
                      box.maxWidth *
                      .3 *
                      progress,
              top: 20,
              child: Icon(
                Icons.touch_app_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Ilustraciones locales de práctica: no se solicita acceso a la galería.
class _GalleryPainter extends CustomPainter {
  const _GalleryPainter(this.index);
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final night = index == 2;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night
              ? [AppColors.primaryDark, AppColors.primary]
              : [AppColors.primaryLight, AppColors.surface],
        ).createShader(Offset.zero & size),
    );
    final sun = Offset(w * .75, h * .25);
    canvas.drawCircle(
      sun,
      w * .09,
      Paint()..color = night ? AppColors.surface : AppColors.accent,
    );
    if (night) {
      canvas.drawCircle(
        sun + Offset(w * .04, -h * .025),
        w * .08,
        Paint()..color = AppColors.primaryDark,
      );
      for (final point in [
        const Offset(.2, .15),
        const Offset(.45, .3),
        const Offset(.15, .4),
        const Offset(.55, .12),
      ]) {
        canvas.drawCircle(
          Offset(point.dx * w, point.dy * h),
          2.5,
          Paint()..color = AppColors.surface,
        );
      }
    }
    final hills = Path()
      ..moveTo(0, h * .76)
      ..quadraticBezierTo(w * .2, h * .35, w * .5, h * .72)
      ..quadraticBezierTo(w * .75, h * .45, w, h * .65)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      hills,
      Paint()
        ..color = night
            ? AppColors.primaryDark
            : AppColors.primary.withValues(alpha: .35),
    );
    if (index == 1) {
      final mountain = Path()
        ..moveTo(w * .1, h)
        ..lineTo(w * .46, h * .25)
        ..lineTo(w * .85, h)
        ..close();
      canvas.drawPath(mountain, Paint()..color = AppColors.primary);
      final peak = Path()
        ..moveTo(w * .36, h * .46)
        ..lineTo(w * .46, h * .25)
        ..lineTo(w * .57, h * .46)
        ..close();
      canvas.drawPath(peak, Paint()..color = AppColors.surface);
    } else if (index == 0) {
      for (final x in [.22, .48, .73]) {
        final center = Offset(x * w, h * .66);
        canvas.drawLine(
          center,
          Offset(x * w, h),
          Paint()
            ..color = AppColors.primaryDark
            ..strokeWidth = 4,
        );
        for (var petal = 0; petal < 6; petal++) {
          final angle = petal * math.pi / 3;
          canvas.drawCircle(
            center + Offset(math.cos(angle), math.sin(angle)) * (w * .035),
            w * .025,
            Paint()..color = AppColors.primary,
          );
        }
        canvas.drawCircle(center, w * .022, Paint()..color = AppColors.accent);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GalleryPainter oldDelegate) =>
      index != oldDelegate.index;
}
