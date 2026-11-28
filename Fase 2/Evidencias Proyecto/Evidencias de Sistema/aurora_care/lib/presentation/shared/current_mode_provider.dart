// lib/presentation/shared/current_mode_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Refleja el modo de la sesión restaurada y los cambios confirmados por
// el repositorio. No concede permisos al cuidador ni reemplaza su revocación.
final currentModeProvider = StateProvider<int>((ref) => 2);
