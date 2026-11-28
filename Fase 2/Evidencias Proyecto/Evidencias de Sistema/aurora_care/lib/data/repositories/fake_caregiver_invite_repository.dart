// lib/data/repositories/fake_caregiver_invite_repository.dart
import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/caregiver_invite.dart';
import '../../domain/entities/invite_status.dart';
import '../../domain/repositories/caregiver_invite_repository.dart';

/// Repositorio simulado reservado a pruebas. La aplicación utiliza
/// FirestoreCaregiverInviteRepository; este doble no concede vínculos reales.
class FakeCaregiverInviteRepository implements CaregiverInviteRepository {
  FakeCaregiverInviteRepository(
    this._prefs, {
    Random? random,
    DateTime Function()? now,
  }) : _random = random ?? Random(),
       _now = now ?? DateTime.now;

  /// Prefijo TEMPORAL — solo existe mientras este fake exista.
  static const _keyToken = 'fake_caregiver_invite_v1_token';
  static const _keyExpiresAt = 'fake_caregiver_invite_v1_expiresAt';

  final SharedPreferences _prefs;
  final Random _random;
  final DateTime Function() _now;

  final _controllers = <String, StreamController<InviteStatus>>{};
  final _timers = <String, Timer>{};

  /// Token marcado como canjeado por simulateRedeemed(). No se persiste:
  /// alcanza con que dure mientras la app sigue abierta observándolo.
  String? _redeemedToken;

  CaregiverInvite? _leerPersistido() {
    final token = _prefs.getString(_keyToken);
    final expiresAtMillis = _prefs.getInt(_keyExpiresAt);
    if (token == null || expiresAtMillis == null) return null;
    return CaregiverInvite(
      token: token,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMillis),
    );
  }

  Future<void> _guardar(CaregiverInvite invite) async {
    await _prefs.setString(_keyToken, invite.token);
    await _prefs.setInt(_keyExpiresAt, invite.expiresAt.millisecondsSinceEpoch);
  }

  Future<void> _borrarPersistido() async {
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyExpiresAt);
  }

  String _tokenAleatorio() {
    const caracteres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      8,
      (_) => caracteres[_random.nextInt(caracteres.length)],
    ).join();
  }

  InviteStatus _estadoDe(CaregiverInvite invite) {
    if (invite.token == _redeemedToken) return InviteStatus.redeemed;
    if (!invite.expiresAt.isAfter(_now())) return InviteStatus.expired;
    return InviteStatus.active;
  }

  @override
  Future<CaregiverInvite> createInvite() async {
    final anterior = _leerPersistido();
    if (anterior != null) {
      _timers.remove(anterior.token)?.cancel();
      // La anterior queda reemplazada: ya no es válida.
      _emitir(anterior.token, InviteStatus.expired);
    }
    _redeemedToken = null;

    final invite = CaregiverInvite(
      token: _tokenAleatorio(),
      expiresAt: _now().add(const Duration(minutes: 10)),
    );
    await _guardar(invite);
    _emitir(invite.token, InviteStatus.active);
    _programarVencimiento(invite);
    return invite;
  }

  @override
  Future<CaregiverInvite?> getActiveInvite() async {
    final invite = _leerPersistido();
    if (invite == null) return null;
    if (_estadoDe(invite) != InviteStatus.active) return null;
    return invite;
  }

  @override
  Stream<InviteStatus> watchInvite(String token) {
    final controller = _controllers.putIfAbsent(
      token,
      () => StreamController<InviteStatus>.broadcast(),
    );

    // Informa el estado real vigente al suscribirse: si la app se
    // cerró y reabrió, el Timer en memoria ya no existe, pero el
    // estado persistido sigue siendo la fuente de verdad.
    final persistido = _leerPersistido();
    if (persistido != null && persistido.token == token) {
      final estado = _estadoDe(persistido);
      scheduleMicrotask(() => controller.add(estado));
      if (estado == InviteStatus.active) _programarVencimiento(persistido);
    }

    return controller.stream;
  }

  @override
  Future<void> cancelInvite(String token) async {
    _timers.remove(token)?.cancel();
    final actual = _leerPersistido();
    if (actual?.token == token) await _borrarPersistido();
    _emitir(token, InviteStatus.expired);
  }

  @override
  Future<void> cancelAllInvites() async {
    final persisted = _leerPersistido();
    final tokens = {
      ..._controllers.keys,
      if (persisted != null) persisted.token,
    };
    // No basta con getActiveInvite: una invitación simulada como usada
    // también debe desaparecer para que no reviva al reiniciar la app.
    if (!await _prefs.remove(_keyToken) ||
        !await _prefs.remove(_keyExpiresAt)) {
      throw StateError('No se pudo cancelar la invitación');
    }
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _redeemedToken = null;
    for (final token in tokens) {
      _emitir(token, InviteStatus.expired);
    }
  }

  @override
  Future<void> redeemInvite(String token) async {
    if ((await getActiveInvite())?.token != token) {
      throw StateError('Invalid invite');
    }
    simulateRedeemed(token);
  }

  @override
  Stream<bool> watchConnection() => Stream.value(_redeemedToken != null);

  /// Solo del fake (no es parte del contrato real): simula que un
  /// cuidador escaneó el código y se vinculó, para poder probar ese
  /// estado sin un backend real.
  void simulateRedeemed(String token) {
    _timers.remove(token)?.cancel();
    _redeemedToken = token;
    _emitir(token, InviteStatus.redeemed);
  }

  void _programarVencimiento(CaregiverInvite invite) {
    _timers[invite.token]?.cancel();
    final restante = invite.expiresAt.difference(_now());
    _timers[invite.token] = Timer(
      restante.isNegative ? Duration.zero : restante,
      () => _emitir(invite.token, InviteStatus.expired),
    );
  }

  void _emitir(String token, InviteStatus status) {
    _controllers[token]?.add(status);
  }

  /// Cancela los timers de vencimiento pendientes y cierra los streams.
  /// Solo del fake: la implementación real no tiene este problema
  /// porque el vencimiento lo detecta Firestore, no un Timer local.
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}
