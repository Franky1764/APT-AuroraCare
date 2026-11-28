// lib/presentation/games/shared/game_shell.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/router/navigation_session.dart';
import '../../../core/audio/sound_effect.dart';
import '../../../core/providers/accessibility_providers.dart';
import '../../../core/providers/sound_providers.dart';
import '../../../data/sources/practice_feedback_platform.dart';
import '../../../data/repositories/session_repository_impl.provider.dart';
import '../../caregiver_dashboard/shared_practice_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/cognitive_metrics.dart';
import '../../../domain/entities/cognitive_profile.dart';
import '../../../domain/entities/game_level.dart';
import '../../../domain/entities/session.dart';
import '../../../domain/entities/session_analysis.dart';
import '../../../domain/usecases/finish_session.dart';
import '../../../domain/usecases/finish_session.provider.dart';
import 'game_definition.dart';
import 'game_providers.dart';
import 'game_result_screen.dart';
import '../../progress/progress_providers.dart';

/// Cascarón común de los 9 juegos: tiempo, salida con confirmación,
/// guardado de la sesión (solo Modo 2 y 3) y paso al resultado.
class GameShell extends ConsumerStatefulWidget {
  const GameShell({super.key, required this.definition, required this.nivel});

  final GameDefinition definition;
  final GameLevel nivel;

  @override
  ConsumerState<GameShell> createState() => _GameShellState();
}

class _GameShellState extends ConsumerState<GameShell> {
  final _watch = Stopwatch();
  final _startTime = DateTime.now();
  Timer? _ticker;
  bool _finished = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // De siempre, el reloj arranca apenas se entra al juego. Memorice
    // clásico es la excepción (su vista previa todavía no es "jugar"):
    // retrasa el arranque llamando a run.startClock cuando corresponda.
    if (widget.definition.startClockImmediately) {
      _watch.start();
    }
    // Solo se reconstruye cada segundo cuando hay un reloj visible.
    // Trazado mide su tiempo activo mediante los eventos del recorrido.
    if (widget.definition.showElapsedTime) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !_saving) setState(() {});
      });
    }
    final sound = ref.read(soundServiceProvider);
    unawaited(sound.stopMusic());
    if (ref.read(soundsEnabledProvider)) {
      unawaited(sound.play(SoundEffect.inicioPartida));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<bool> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quiere salir?', style: AppTextStyles.heading),
        content: Text(
          'Si sale ahora, esta partida no se guardará.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Seguir jugando',
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Salir',
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return exit ?? false;
  }

  Future<void> _requestExit() async {
    if (_saving) return;
    final exit = await _confirmExit();
    if (exit && mounted) Navigator.of(context).pop();
  }

  Future<void> _onFinish(CognitiveMetrics metrics) async {
    if (_finished) return;
    _finished = true;
    _watch.stop();
    _ticker?.cancel();
    setState(() => _saving = true);

    final end = DateTime.now();
    final account = ref.read(navigationSessionProvider).session?.uid;
    SessionAnalysis? analysis;
    var recorded = false;

    CognitiveProfile? profile;
    try {
      profile = await ref.read(activeProfileProvider.future);
    } catch (_) {
      profile = null;
    }

    // Con perfil activo se guarda y se analiza la sesión. Sin perfil (aún no se
    // eligió modo o no se pudo leer) no se guarda nada.
    if (profile != null) {
      final session = Session(
        sessionId: const Uuid().v4(),
        uuid: profile.uuid,
        domain: widget.definition.domain,
        gameType: widget.definition.gameType,
        nivel: widget.nivel,
        startTime: _startTime,
        endTime: end,
        metrics: metrics,
      );
      try {
        final result = await ref.read(finishSessionProvider)(
          FinishSessionParams(session),
        );
        analysis = result.analysis;
        recorded = true;
        if (!mounted) return;
        if (account != null &&
            ref.read(navigationSessionProvider).session?.uid == account) {
          unawaited(
            ref
                .read(practiceFeedbackPlatformProvider)
                .recordPractice(account, end),
          );
        }
        ref.invalidate(progressProvider);
        if (ref.read(navigationSessionProvider).session?.currentMode == 3) {
          final sharing = ref.read(sharedPracticeRepositoryProvider);
          if (sharing != null) {
            final sessions = ref.read(sessionRepositoryProvider);
            final uuid = profile.uuid;
            unawaited(
              sharing
                  .refreshSharedSummary(() async {
                    final recent = await sessions.getSessionsInWindow(
                      uuid,
                      days: 28,
                    );
                    return sharedPracticeData(
                      summarizeProgress(
                        recent.any(
                              (saved) => saved.sessionId == session.sessionId,
                            )
                            ? recent
                            : [...recent, session],
                        uuid: uuid,
                        now: DateTime.now(),
                      ),
                    );
                  })
                  .catchError((Object _) {
                    // Una falla al compartir no cambia el resultado de la partida.
                    debugPrint('AuroraCare: resumen compartido pendiente');
                  }),
            );
          }
        }
      } catch (e) {
        debugPrint('GameShell: no se pudo guardar la sesión: $e');
      }
    }

    if (!mounted) return;
    if (ref.read(soundsEnabledProvider)) {
      unawaited(
        ref
            .read(soundServiceProvider)
            .play(SoundEffect.resultado(analysis?.scoreSesion)),
      );
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameResultScreen(
          title: widget.definition.title,
          nivel: widget.nivel,
          analysis: analysis,
          metrics: metrics,
          gameType: widget.definition.gameType,
          recorded: recorded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final run = GameRun(
      nivel: widget.nivel,
      maxDuration: widget.definition.maxDuration(widget.nivel),
      elapsed: () => _watch.elapsed,
      pauseClock: _watch.stop,
      resumeClock: () {
        if (mounted && !_finished) _watch.start();
      },
      startClock: () {
        if (mounted && !_finished) _watch.start();
      },
      finish: _onFinish,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Salir',
            onPressed: _requestExit,
          ),
          title: Text(
            widget.definition.showElapsedTime
                ? _format(_watch.elapsed)
                : widget.definition.title,
            style: AppTextStyles.body,
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _saving
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('Un momento…', style: AppTextStyles.bodySecondary),
                    ],
                  ),
                )
              : widget.definition.builder(context, run),
        ),
      ),
    );
  }
}
