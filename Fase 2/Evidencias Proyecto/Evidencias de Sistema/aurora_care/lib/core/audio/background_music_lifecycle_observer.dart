// lib/core/audio/background_music_lifecycle_observer.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sound_providers.dart';

/// Observador de ciclo de vida de alcance global, insertado una sola vez
/// envolviendo el contenido de AuroraCareApp (ver main.dart). Pausa la
/// música de fondo cuando la app pasa a segundo plano
/// (AppLifecycleState.paused o .inactive, p. ej. una llamada entrante o
/// el botón de inicio) y la reanuda al volver (.resumed), pero solo si
/// estaba sonando justo antes de pausarse — nunca reanuda música que el
/// usuario tiene desactivada, ni la "revive" si ya estaba detenida.
class BackgroundMusicLifecycleObserver extends ConsumerStatefulWidget {
  const BackgroundMusicLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BackgroundMusicLifecycleObserver> createState() =>
      _BackgroundMusicLifecycleObserverState();
}

class _BackgroundMusicLifecycleObserverState
    extends ConsumerState<BackgroundMusicLifecycleObserver>
    with WidgetsBindingObserver {
  // null: la app está en primer plano. true/false: está en segundo
  // plano, y recuerda si había música sonando justo antes de pausarla
  // (se fija solo en la primera transición de cada pasada a segundo
  // plano, con inactive/paused pudiendo llegar varias veces seguidas).
  bool? _sonabaAntesDeSegundoPlano;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sound = ref.read(soundServiceProvider);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _sonabaAntesDeSegundoPlano ??= sound.isMusicPlaying;
        unawaited(sound.pauseMusic());
      case AppLifecycleState.resumed:
        if (_sonabaAntesDeSegundoPlano == true) {
          unawaited(sound.resumeMusic());
        }
        _sonabaAntesDeSegundoPlano = null;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
