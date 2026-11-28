// lib/data/sources/audioplayers_sound_service.dart

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../../core/audio/sound_effect.dart';
import '../../core/audio/sound_service.dart';

/// Implementación real de [SoundService] con el paquete audioplayers.
///
/// usageType "game" y audioFocus "none" en Android, tanto para la
/// música como para los efectos: la app nunca pide ni cede el foco de
/// audio de forma permanente, así que un efecto y la música pueden
/// sonar mezclados sin pelear por el foco del sistema. El "bajar el
/// volumen" al sonar un efecto lo hace esta clase a mano (achica y
/// restaura el volumen de la música), no es algo que haga Android.
///
/// Igual que PracticeFeedbackPlatform: cualquier falla de la plataforma
/// (plugin no disponible, archivo de audio faltante, etc.) se atrapa y
/// se ignora — un problema de audio nunca debe interrumpir un juego.
class AudioPlayersSoundService implements SoundService {
  static const double _volumenMusica = 0.4;
  static const double _volumenMusicaConEfecto = 0.15;
  AudioPlayersSoundService(this._effectVolume);

  final double Function() _effectVolume;

  /// Cuántas veces puede sonar superpuesto el MISMO efecto (p. ej. dos
  /// cartas volteándose casi juntas).
  static const int _reproductoresPorEfecto = 2;

  static final _contextoMusica = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  static final _contextoEfectos = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  final AudioPlayer _music = AudioPlayer(playerId: 'aurora_care_music');
  final Map<SoundEffect, AudioPool> _pools = {};
  final Map<SoundEffect, Duration> _duraciones = {};

  bool _musicaConfigurada = false;
  bool _musicEnabled = true;
  MusicTrack? _trackActual;
  Timer? _restaurarVolumenTimer;

  @override
  Future<void> preload() async {
    try {
      if (!_musicaConfigurada) {
        await _music.setAudioContext(_contextoMusica);
        await _music.setReleaseMode(ReleaseMode.loop);
        await _music.setVolume(_volumenMusica);
        _musicaConfigurada = true;
      }
    } on MissingPluginException {
      // Sin plugin nativo (p. ej. algunos entornos de prueba): sin música.
    } on PlatformException {
      // No se pudo preparar el reproductor: la app sigue sin él.
    }
    await Future.wait(SoundEffect.values.map(_poolPara));
  }

  /// Crea (o reutiliza) el AudioPool de [effect]. Cada efecto queda
  /// precargado con su propio grupo de reproductores, listo para sonar
  /// sin demora. Si el archivo no se pudo cargar, devuelve null en vez
  /// de propagar el error — ese efecto, nada más, se queda mudo.
  Future<AudioPool?> _poolPara(SoundEffect effect) async {
    final existente = _pools[effect];
    if (existente != null) return existente;
    try {
      final pool = await AudioPool.create(
        source: AssetSource(effect.assetPath),
        audioContext: _contextoEfectos,
        minPlayers: 1,
        maxPlayers: _reproductoresPorEfecto,
      );
      _pools[effect] = pool;
      _duraciones[effect] =
          await pool.getDuration() ?? const Duration(milliseconds: 800);
      return pool;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> play(SoundEffect effect) async {
    final pool = await _poolPara(effect);
    if (pool == null) return;
    try {
      final duracion = _duraciones[effect] ?? const Duration(milliseconds: 800);
      await _music.setVolume(_volumenMusicaConEfecto);
      await pool.start(volume: _effectVolume());

      // Restaura el volumen de la música cuando este efecto termina. Si
      // suena otro efecto antes de que esto se cumpla, el nuevo Timer
      // simplemente reemplaza a este (la ventana de "bajo volumen" se
      // extiende en vez de restaurar a mitad de un segundo efecto).
      _restaurarVolumenTimer?.cancel();
      _restaurarVolumenTimer = Timer(
        duracion + const Duration(milliseconds: 80),
        () {
          if (_musicEnabled) {
            unawaited(_music.setVolume(_volumenMusica));
          }
        },
      );
    } on MissingPluginException {
      // Sin plugin nativo: sin efecto, sin interrumpir el juego.
    } on PlatformException {
      // No se pudo reproducir: seguimos sin el efecto, sin interrumpir el juego.
    }
  }

  @override
  Future<void> playMusic(MusicTrack track) async {
    if (!_musicEnabled) return;
    try {
      if (_trackActual != track) {
        await _music.setAudioContext(_contextoMusica);
        await _music.setReleaseMode(ReleaseMode.loop);
        await _music.setSource(AssetSource(track.assetPath));
        await _music.setVolume(_volumenMusica);
        _trackActual = track;
      } else if (_music.state == PlayerState.playing) {
        return; // Ya está sonando esta misma pista: no la reinicia.
      }
      await _music.resume();
    } on MissingPluginException {
      // Sin plugin nativo: sin música, sin interrumpir la app.
    } on PlatformException {
      // No se pudo reproducir: la app sigue sin música de fondo.
    }
  }

  @override
  Future<void> pauseMusic() async {
    try {
      await _music.pause();
    } on MissingPluginException {
      // Sin plugin nativo: nada que pausar.
    } on PlatformException {
      // No se pudo pausar: no hay nada más que hacer.
    }
  }

  @override
  Future<void> resumeMusic() async {
    if (!_musicEnabled || _trackActual == null) return;
    try {
      await _music.resume();
    } on MissingPluginException {
      // Sin plugin nativo: nada que reanudar.
    } on PlatformException {
      // No se pudo reanudar: no hay nada más que hacer.
    }
  }

  @override
  Future<void> stopMusic() async {
    try {
      await _music.stop();
      _trackActual = null;
    } on MissingPluginException {
      // Sin plugin nativo: nada que detener.
    } on PlatformException {
      // No se pudo detener: no hay nada más que hacer.
    }
  }

  @override
  bool get isMusicPlaying =>
      _musicEnabled && _music.state == PlayerState.playing;

  @override
  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) {
      unawaited(stopMusic());
    }
  }

  @override
  void dispose() {
    _restaurarVolumenTimer?.cancel();
    unawaited(_music.dispose());
    for (final pool in _pools.values) {
      unawaited(pool.dispose());
    }
    _pools.clear();
    _duraciones.clear();
  }
}
