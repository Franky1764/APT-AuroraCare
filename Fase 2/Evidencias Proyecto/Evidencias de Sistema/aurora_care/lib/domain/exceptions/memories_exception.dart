// domain/exceptions/memories_exception.dart

/// Lanzada cuando falla un guardado local de "Mis recuerdos" (por
/// ejemplo, SharedPreferences no pudo escribir). La pantalla debe mostrar
/// un mensaje claro a la persona — nunca registrar el contenido en logs.
class MemoriesStorageException implements Exception {
  const MemoriesStorageException([
    this.message = 'No se pudo guardar. Intente de nuevo.',
  ]);

  final String message;

  @override
  String toString() => message;
}
