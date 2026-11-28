// lib/core/audio/music_route_scope.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/accessibility_providers.dart';
import '../providers/sound_providers.dart';
import '../router/navigation_session.dart';
import 'sound_effect.dart';

/// Observador de rutas de alcance global para la música de fondo. Se
/// registra una sola vez en el GoRouter (ver core/router/app_router.dart,
/// parámetro `observers`). Como Home, Perfil y el resto de las pantallas
/// que se abren desde Home viven en el mismo Navigator que administra
/// GoRouter (se abren con Navigator.push, no con rutas nuevas), este
/// mismo observador ve tanto las rutas de GoRouter como esos push/pop.
final musicRouteObserver = RouteObserver<ModalRoute<void>>();

/// Envuelve una pantalla para que suene [track] mientras esté visible,
/// sin depender solo de initState (que no se vuelve a llamar al volver a
/// una pantalla que ya existía, por ejemplo al cerrar un juego y volver
/// al menú). Usa RouteAware sobre [musicRouteObserver]:
/// - Al entrar o volver a quedar visible (didPush / didPopNext): pide
///   [track], si el ajuste de música está activo.
/// - Al salir (didPop, esta pantalla se quita de la pila): vuelve a
///   pedir la pista ambiente de la app (musica_menu). Así, una pantalla
///   con otra pista (como la sesión de respiración, con musica_calma) la
///   devuelve de inmediato al cerrarse, sin depender de qué pantalla
///   quede más abajo en la pila. Para Home y Perfil (que ya quieren
///   musica_menu) este mismo llamado es un no-op audible, por la
///   comprobación de idempotencia de playMusic().
///
/// No pide música si no hay una sesión de adulto mayor activa: evita que
/// un didPop disparado por el reemplazo de toda la pila al cerrar sesión
/// vuelva a encender la música justo después de que el cierre de sesión
/// la detiene explícitamente.
class MusicRouteScope extends ConsumerStatefulWidget {
  const MusicRouteScope({super.key, required this.track, required this.child});

  final MusicTrack track;
  final Widget child;

  @override
  ConsumerState<MusicRouteScope> createState() => _MusicRouteScopeState();
}

class _MusicRouteScopeState extends ConsumerState<MusicRouteScope>
    with RouteAware {
  ModalRoute<void>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      if (_route != null) musicRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) musicRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    musicRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() => _sonarPropia();

  @override
  void didPopNext() => _sonarPropia();

  @override
  void didPop() => _sonarAmbiente();

  bool get _haySesionActiva =>
      ref.read(navigationSessionProvider).session != null;

  void _sonarPropia() {
    if (!mounted || !_haySesionActiva) return;
    if (ref.read(musicEnabledProvider)) {
      unawaited(ref.read(soundServiceProvider).playMusic(widget.track));
    }
  }

  void _sonarAmbiente() {
    if (!mounted || !_haySesionActiva) return;
    if (ref.read(musicEnabledProvider)) {
      unawaited(ref.read(soundServiceProvider).playMusic(MusicTrack.menu));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
