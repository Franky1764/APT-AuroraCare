import '../repositories/auth_repository.dart';

class ChangeUsageMode {
  const ChangeUsageMode(this._repository);

  final AuthRepository _repository;

  Future<void> call({
    required String uid,
    required int currentMode,
    required int mode,
  }) async {
    if (mode != 2 && mode != 3) {
      throw ArgumentError.value(mode, 'mode', 'Debe ser 2 o 3');
    }
    // El repositorio confirma el cambio en el servidor. El modo no determina
    // la identidad del perfil ni autoriza por sí mismo a un cuidador.
    await _repository.updateCurrentMode(uid: uid, mode: mode);
  }
}
