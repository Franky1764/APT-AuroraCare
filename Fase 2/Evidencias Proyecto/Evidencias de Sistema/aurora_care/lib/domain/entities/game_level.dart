// domain/entities/game_level.dart
enum GameLevel {
  facil(1, 'Fácil'),
  intermedio(2, 'Intermedio'),
  avanzado(3, 'Avanzado');

  const GameLevel(this.value, this.label);
  final int value;
  final String label;

  static GameLevel fromValue(int v) =>
      values.firstWhere((l) => l.value == v);
}