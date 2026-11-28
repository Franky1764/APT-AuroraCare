// lib/core/audio/sound_service.dart

import 'sound_effect.dart';

/// Interfaz del sistema de sonido: efectos cortos y música de fondo.
/// Dart puro (nada de Flutter ni de audioplayers acá), para poder
/// sobreescribirla en tests con un falso que no toca audio real.
///
/// `play()` no filtra por el ajuste "Sonidos": quien llama decide si
/// corresponde (igual que ya hace GameShell con soundsEnabledProvider
/// antes de reproducir el beep nativo). La música sí se filtra adentro,
/// con [setMusicEnabled], porque se inicia desde varios lugares
/// distintos (menú, perfil, respiración) y conviene un solo interruptor
/// central en vez de repetir la misma comprobación en cada uno.
abstract class SoundService {
  /// Precarga los efectos cortos para que `play()` no tenga demora la
  /// primera vez que se usa cada uno. Llamarla más de una vez no hace
  /// nada raro (una implementación real solo precarga una vez).
  Future<void> preload();

  /// Reproduce un efecto corto. Varios efectos pueden sonar casi al
  /// mismo tiempo sin cortarse entre sí.
  Future<void> play(SoundEffect effect);

  /// Reproduce [track] en bucle. Si esa misma pista ya está sonando, no
  /// la reinicia. No hace nada si la música está deshabilitada (ver
  /// [setMusicEnabled]).
  Future<void> playMusic(MusicTrack track);

  /// Pausa la música donde está (para reanudarla después con
  /// [resumeMusic], por ejemplo al volver de segundo plano).
  Future<void> pauseMusic();

  /// Reanuda la música pausada. No hace nada si no había ninguna pista
  /// pausada, o si la música está deshabilitada.
  Future<void> resumeMusic();

  /// Detiene la música por completo (no queda nada para reanudar).
  Future<void> stopMusic();

  /// true si la música de fondo está sonando en este momento (no
  /// pausada, no detenida, no deshabilitada). La usa el observador de
  /// ciclo de vida de la app (ver
  /// core/audio/background_music_lifecycle_observer.dart) para decidir
  /// si debe reanudarla al volver del segundo plano.
  bool get isMusicPlaying;

  /// Habilita o deshabilita la música de fondo. En false, [playMusic] no
  /// hace nada y cualquier música en curso se detiene de inmediato.
  void setMusicEnabled(bool enabled);

  /// Libera los reproductores. Llamar al destruir el provider.
  void dispose();
}
