// domain/usecases/stream_usecase.dart

/// Mismo molde que UseCase (usecase.dart), pero para casos de uso que
/// entregan un flujo continuo de valores en vez de un único resultado
/// (ej: observar cambios en tiempo real). UseCase solo contempla
/// Future; este es el mínimo necesario para Stream, sin inventar un
/// patrón nuevo.
abstract class StreamUseCase<ReturnType, Params> {
  Stream<ReturnType> call(Params params);
}
