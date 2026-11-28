// lib/core/providers/sound_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/audioplayers_sound_service.dart';
import '../audio/sound_service.dart';
import 'accessibility_providers.dart';

/// Sobreescribible en tests con un FakeSoundService (ver
/// test/helpers/fake_sound_service.dart) para no tocar audio real.
final soundServiceProvider = Provider<SoundService>((ref) {
  final service = AudioPlayersSoundService(
    () => switch (ref.read(soundLevelProvider)) {
      1 => 0.3,
      2 => 0.6,
      _ => 1.0,
    },
  );
  ref.onDispose(service.dispose);
  return service;
});
