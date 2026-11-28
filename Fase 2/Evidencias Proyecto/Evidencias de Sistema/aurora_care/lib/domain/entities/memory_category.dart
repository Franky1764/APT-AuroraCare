// domain/entities/memory_category.dart

/// Una categoría de "Mis recuerdos" (juego de memoria personalizado,
/// presentation/games/memoria/mis_recuerdos/). Fase 1: solo las 3
/// predeterminadas existen, no hay categorías propias todavía.
class MemoryCategory {
  const MemoryCategory({
    required this.id,
    required this.name,
    required this.isPredefined,
    required this.iconKey,
  });

  /// 'familia' | 'musica' | 'fechas' en fase 1.
  final String id;

  final String name;
  final bool isPredefined;

  /// Clave simple para que presentation/ elija un ícono, sin que domain/
  /// dependa de Flutter (IconData).
  final String iconKey;
}
