import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/core/audio/sound_effect.dart';

import '../../helpers/fake_sound_service.dart';

void main() {
  group('SoundEffect.acierto', () {
    test('devuelve acierto1..acierto5 según la racha', () {
      expect(SoundEffect.acierto(1), SoundEffect.acierto1);
      expect(SoundEffect.acierto(2), SoundEffect.acierto2);
      expect(SoundEffect.acierto(3), SoundEffect.acierto3);
      expect(SoundEffect.acierto(4), SoundEffect.acierto4);
      expect(SoundEffect.acierto(5), SoundEffect.acierto5);
    });

    test('rachas de 6 o más se quedan en acierto5 (no hace falta un '
        'sonido por cada racha posible)', () {
      expect(SoundEffect.acierto(6), SoundEffect.acierto5);
      expect(SoundEffect.acierto(100), SoundEffect.acierto5);
    });

    test('rachas de 0 o negativas caen en acierto1, sin reventar', () {
      expect(SoundEffect.acierto(0), SoundEffect.acierto1);
      expect(SoundEffect.acierto(-3), SoundEffect.acierto1);
    });
  });

  group('SoundEffect.secuenciaNota', () {
    test('un paso por nota, en orden', () {
      expect(SoundEffect.secuenciaNota(0), SoundEffect.secuenciaNota1);
      expect(SoundEffect.secuenciaNota(1), SoundEffect.secuenciaNota2);
      expect(SoundEffect.secuenciaNota(2), SoundEffect.secuenciaNota3);
      expect(SoundEffect.secuenciaNota(3), SoundEffect.secuenciaNota4);
    });

    test('se repite en ciclo si la secuencia tiene más de 4 pasos', () {
      expect(SoundEffect.secuenciaNota(4), SoundEffect.secuenciaNota1);
      expect(SoundEffect.secuenciaNota(7), SoundEffect.secuenciaNota4);
    });
  });

  group('SoundEffect.resultado', () {
    test('>=70 es excelente', () {
      expect(SoundEffect.resultado(85), SoundEffect.resultadoExcelente);
      expect(SoundEffect.resultado(70), SoundEffect.resultadoExcelente);
    });

    test('entre 40 (inclusive) y 70 (exclusive) es bien', () {
      expect(SoundEffect.resultado(69.9), SoundEffect.resultadoBien);
      expect(SoundEffect.resultado(40), SoundEffect.resultadoBien);
    });

    test('menos de 40 es ánimo', () {
      expect(SoundEffect.resultado(39.9), SoundEffect.resultadoAnimo);
      expect(SoundEffect.resultado(0), SoundEffect.resultadoAnimo);
    });

    test('sin análisis (null) es bien: neutral y positivo, no "le fue mal"', () {
      expect(SoundEffect.resultado(null), SoundEffect.resultadoBien);
    });
  });

  test('cada efecto tiene una ruta de asset propia, distinta y no vacía', () {
    final rutas = SoundEffect.values.map((e) => e.assetPath).toSet();
    expect(rutas.length, SoundEffect.values.length);
    expect(rutas.every((r) => r.isNotEmpty), isTrue);
  });

  test('cada pista de música tiene una ruta de asset propia y distinta', () {
    final rutas = MusicTrack.values.map((t) => t.assetPath).toSet();
    expect(rutas.length, MusicTrack.values.length);
    expect(rutas.every((r) => r.isNotEmpty), isTrue);
  });

  testWidgets('los efectos y las pistas existen en el paquete Flutter', (_) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();
    for (final path in [
      ...SoundEffect.values.map((effect) => effect.assetPath),
      ...MusicTrack.values.map((track) => track.assetPath),
    ]) {
      expect(assets, contains('assets/$path'));
    }
  });

  group('FakeSoundService', () {
    test('play() guarda los efectos reproducidos, en orden', () async {
      final fake = FakeSoundService();
      await fake.play(SoundEffect.acierto1);
      await fake.play(SoundEffect.errorSuave);
      expect(fake.played, [SoundEffect.acierto1, SoundEffect.errorSuave]);
    });

    test('playMusic() guarda la pista, salvo que la música esté '
        'deshabilitada', () async {
      final fake = FakeSoundService();
      await fake.playMusic(MusicTrack.menu);
      expect(fake.musicStarted, [MusicTrack.menu]);

      fake.setMusicEnabled(false);
      await fake.playMusic(MusicTrack.calma);
      expect(fake.musicStarted, [MusicTrack.menu]); // no se agregó nada más.
    });

    test('pauseMusic()/resumeMusic()/stopMusic() cuentan sus llamadas', () async {
      final fake = FakeSoundService();
      await fake.pauseMusic();
      await fake.resumeMusic();
      await fake.stopMusic();
      expect(fake.musicPausedCount, 1);
      expect(fake.musicResumedCount, 1);
      expect(fake.musicStoppedCount, 1);
    });

    test('setMusicEnabled(false) cuenta como una detención', () {
      final fake = FakeSoundService();
      fake.setMusicEnabled(false);
      expect(fake.musicEnabled, isFalse);
      expect(fake.musicStoppedCount, 1);
    });
  });
}
