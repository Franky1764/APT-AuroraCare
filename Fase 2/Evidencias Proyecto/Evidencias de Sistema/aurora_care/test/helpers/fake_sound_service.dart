import 'package:aurora_care/core/audio/sound_effect.dart';
import 'package:aurora_care/core/audio/sound_service.dart';

/// No toca audio real: guarda lo que se le pidió reproducir para poder
/// afirmarlo en los tests (o afirmar que no se reprodujo nada, cuando
/// corresponde).
class FakeSoundService implements SoundService {
  final List<SoundEffect> played = [];
  final List<MusicTrack> musicStarted = [];
  int musicStoppedCount = 0;
  int musicPausedCount = 0;
  int musicResumedCount = 0;
  bool musicEnabled = true;
  @override
  bool isMusicPlaying = false;

  @override
  Future<void> preload() async {}

  @override
  Future<void> play(SoundEffect effect) async {
    played.add(effect);
  }

  @override
  Future<void> playMusic(MusicTrack track) async {
    if (!musicEnabled) return;
    // Igual que AudioPlayersSoundService: pedir la misma pista que ya
    // está sonando no la reinicia.
    if (isMusicPlaying && musicStarted.isNotEmpty && musicStarted.last == track) {
      return;
    }
    musicStarted.add(track);
    isMusicPlaying = true;
  }

  @override
  Future<void> pauseMusic() async {
    musicPausedCount++;
    isMusicPlaying = false;
  }

  @override
  Future<void> resumeMusic() async {
    if (!musicEnabled) return;
    musicResumedCount++;
    isMusicPlaying = true;
  }

  @override
  Future<void> stopMusic() async {
    musicStoppedCount++;
    isMusicPlaying = false;
  }

  @override
  void setMusicEnabled(bool enabled) {
    musicEnabled = enabled;
    if (!enabled) {
      musicStoppedCount++;
      isMusicPlaying = false;
    }
  }

  @override
  void dispose() {}
}
