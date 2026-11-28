// lib/core/audio/sound_effect.dart

/// Un efecto de sonido corto (retroalimentación de los juegos). Dart puro:
/// ni Flutter ni ningún paquete de audio, para que domain/ y los tests
/// puedan usarlo sin arrastrar nada de eso.
///
/// [assetPath] es la ruta relativa a `assets/` (sin ese prefijo), tal como
/// la espera `AssetSource` de audioplayers — ver
/// data/sources/audioplayers_sound_service.dart.
enum SoundEffect {
  acierto1('audio/effects/acierto_1.wav'),
  acierto2('audio/effects/acierto_2.wav'),
  acierto3('audio/effects/acierto_3.wav'),
  acierto4('audio/effects/acierto_4.wav'),
  acierto5('audio/effects/acierto_5.wav'),
  errorSuave('audio/effects/error_suave.wav'),
  inicioPartida('audio/effects/inicio_partida.wav'),
  nivelCompletado('audio/effects/nivel_completado.wav'),
  juegoCompletado('audio/effects/juego_completado.wav'),
  resultadoExcelente('audio/effects/resultado_excelente.wav'),
  resultadoBien('audio/effects/resultado_bien.wav'),
  resultadoAnimo('audio/effects/resultado_animo.wav'),
  avisoSuave('audio/effects/aviso_suave.wav'),
  logroDesbloqueado('audio/effects/logro_desbloqueado.wav'),
  cartaVoltear('audio/effects/carta_voltear.wav'),
  parejaEncontrada('audio/effects/pareja_encontrada.wav'),
  secuenciaNota1('audio/effects/secuencia_nota_1.wav'),
  secuenciaNota2('audio/effects/secuencia_nota_2.wav'),
  secuenciaNota3('audio/effects/secuencia_nota_3.wav'),
  secuenciaNota4('audio/effects/secuencia_nota_4.wav'),
  arrastrarTomar('audio/effects/arrastrar_tomar.wav'),
  arrastrarSoltar('audio/effects/arrastrar_soltar.wav'),
  trazadoCompleto('audio/effects/trazado_completo.wav');

  const SoundEffect(this.assetPath);

  final String assetPath;

  static const List<SoundEffect> _aciertos = [
    acierto1,
    acierto2,
    acierto3,
    acierto4,
    acierto5,
  ];

  /// El sonido de acierto según la racha de aciertos consecutivos
  /// [racha] (1 en adelante). Se queda en acierto5 para rachas de 5 o
  /// más: no hace falta un sonido por cada racha posible, solo que la
  /// última etapa sea la más "festejada".
  static SoundEffect acierto(int racha) {
    final indice = racha.clamp(1, _aciertos.length) - 1;
    return _aciertos[indice];
  }

  /// Igual que [secuenciaNota1]..[secuenciaNota4], para el paso [indice]
  /// (0-based) de una secuencia. Se repite en ciclo si la secuencia
  /// tiene más de 4 pasos (no hace falta una nota distinta por cada
  /// paso posible, solo variar el tono de forma perceptible).
  static SoundEffect secuenciaNota(int indice) {
    const notas = [secuenciaNota1, secuenciaNota2, secuenciaNota3, secuenciaNota4];
    return notas[indice % notas.length];
  }

  /// El sonido de cierre de una partida según [scoreSesion] (0..100).
  /// [scoreSesion] es null cuando la sesión quedó sin analizar (sin
  /// conexión o sin perfil activo): en ese caso usa [resultadoBien], un
  /// cierre neutral y positivo — no sabemos cómo le fue, y no debe sonar
  /// a que le fue mal. Umbrales acordados explícitamente, no inventados:
  /// >=70 excelente, >=40 bien, el resto ánimo.
  static SoundEffect resultado(double? scoreSesion) {
    if (scoreSesion == null) return resultadoBien;
    if (scoreSesion >= 70) return resultadoExcelente;
    if (scoreSesion >= 40) return resultadoBien;
    return resultadoAnimo;
  }
}

/// Una pista de música de fondo en bucle. Igual que [SoundEffect]: Dart
/// puro, [assetPath] relativo a `assets/`.
enum MusicTrack {
  menu('audio/music/musica_menu.wav'),
  calma('audio/music/musica_calma.wav');

  const MusicTrack(this.assetPath);

  final String assetPath;
}
