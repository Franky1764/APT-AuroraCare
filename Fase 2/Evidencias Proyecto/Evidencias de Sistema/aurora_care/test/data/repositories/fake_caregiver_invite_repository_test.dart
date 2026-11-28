import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/data/repositories/fake_caregiver_invite_repository.dart';
import 'package:aurora_care/domain/entities/invite_status.dart';

Future<SharedPreferences> _prefsVacias() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  test(
    'createInvite genera un token y expiresAt = ahora + 10 minutos',
    () async {
      final prefs = await _prefsVacias();
      final ahora = DateTime(2026, 1, 1, 12, 0, 0);
      final repo = FakeCaregiverInviteRepository(prefs, now: () => ahora);

      final invite = await repo.createInvite();

      expect(invite.token, isNotEmpty);
      expect(invite.expiresAt, ahora.add(const Duration(minutes: 10)));
    },
  );

  test('cada createInvite genera un token distinto', () async {
    final prefs = await _prefsVacias();
    final repo = FakeCaregiverInviteRepository(prefs);

    final a = await repo.createInvite();
    final b = await repo.createInvite();

    expect(a.token, isNot(b.token));
  });

  test(
    'getActiveInvite devuelve null si nunca se creó una invitación',
    () async {
      final prefs = await _prefsVacias();
      final repo = FakeCaregiverInviteRepository(prefs);

      expect(await repo.getActiveInvite(), isNull);
    },
  );

  test('getActiveInvite devuelve la invitación vigente', () async {
    final prefs = await _prefsVacias();
    final ahora = DateTime(2026, 1, 1, 12, 0, 0);
    final repo = FakeCaregiverInviteRepository(prefs, now: () => ahora);

    final creada = await repo.createInvite();
    final activa = await repo.getActiveInvite();

    expect(activa?.token, creada.token);
  });

  test('getActiveInvite devuelve null una vez pasado expiresAt', () async {
    final prefs = await _prefsVacias();
    var ahora = DateTime(2026, 1, 1, 12, 0, 0);
    final repo = FakeCaregiverInviteRepository(prefs, now: () => ahora);

    await repo.createInvite();
    ahora = ahora.add(const Duration(minutes: 11));

    expect(await repo.getActiveInvite(), isNull);
  });

  test('la invitación persiste en SharedPreferences: otra instancia del fake '
      '(simula reabrir la app) la sigue viendo vigente, con el mismo '
      'expiresAt original', () async {
    final prefs = await _prefsVacias();
    var ahora = DateTime(2026, 1, 1, 12, 0, 0);
    final repoOriginal = FakeCaregiverInviteRepository(prefs, now: () => ahora);
    final creada = await repoOriginal.createInvite();

    ahora = ahora.add(const Duration(minutes: 2));
    final repoReabierto = FakeCaregiverInviteRepository(
      prefs,
      now: () => ahora,
    );

    final activa = await repoReabierto.getActiveInvite();
    expect(activa?.token, creada.token);
    expect(activa?.expiresAt, creada.expiresAt);
  });

  test('watchInvite emite active justo al crear la invitación', () async {
    final prefs = await _prefsVacias();
    final repo = FakeCaregiverInviteRepository(prefs);

    final invite = await repo.createInvite();
    final emitidos = <InviteStatus>[];
    final sub = repo.watchInvite(invite.token).listen(emitidos.add);
    await Future<void>.delayed(Duration.zero);

    expect(emitidos, [InviteStatus.active]);
    await sub.cancel();
  });

  test(
    'al reabrir pasado el vencimiento, watchInvite informa expired de '
    'inmediato (no depende de un Timer en memoria que ya no existe)',
    () async {
      final prefs = await _prefsVacias();
      var ahora = DateTime(2026, 1, 1, 12, 0, 0);
      final repoOriginal = FakeCaregiverInviteRepository(
        prefs,
        now: () => ahora,
      );
      final invite = await repoOriginal.createInvite();

      ahora = ahora.add(const Duration(minutes: 11));
      final repoReabierto = FakeCaregiverInviteRepository(
        prefs,
        now: () => ahora,
      );

      final emitidos = <InviteStatus>[];
      final sub = repoReabierto.watchInvite(invite.token).listen(emitidos.add);
      await Future<void>.delayed(Duration.zero);

      expect(emitidos, [InviteStatus.expired]);
      await sub.cancel();
    },
  );

  test('cancelInvite borra la invitación activa y emite expired', () async {
    final prefs = await _prefsVacias();
    final repo = FakeCaregiverInviteRepository(prefs);
    final invite = await repo.createInvite();

    final emitidos = <InviteStatus>[];
    final sub = repo.watchInvite(invite.token).listen(emitidos.add);
    await Future<void>.delayed(Duration.zero); // recibe el "active" inicial

    await repo.cancelInvite(invite.token);
    await Future<void>.delayed(Duration.zero);

    expect(await repo.getActiveInvite(), isNull);
    expect(emitidos.last, InviteStatus.expired);
    await sub.cancel();
  });

  test('simulateRedeemed marca la invitación como canjeada', () async {
    final prefs = await _prefsVacias();
    final repo = FakeCaregiverInviteRepository(prefs);
    final invite = await repo.createInvite();

    final emitidos = <InviteStatus>[];
    final sub = repo.watchInvite(invite.token).listen(emitidos.add);
    await Future<void>.delayed(Duration.zero); // recibe el "active" inicial

    repo.simulateRedeemed(invite.token);
    await Future<void>.delayed(Duration.zero);

    expect(emitidos.last, InviteStatus.redeemed);
    await sub.cancel();
  });

  test('createInvite descarta la anterior: getActiveInvite devuelve solo la '
      'nueva', () async {
    final prefs = await _prefsVacias();
    final repo = FakeCaregiverInviteRepository(prefs);

    final primera = await repo.createInvite();
    final segunda = await repo.createInvite();

    final activa = await repo.getActiveInvite();
    expect(activa?.token, segunda.token);
    expect(activa?.token, isNot(primera.token));
  });
  for (final state in ['active', 'redeemed', 'expired']) {
    test('cancelAllInvites survives restart for $state invitation', () async {
      final prefs = await _prefsVacias();
      var now = DateTime(2026);
      final repo = FakeCaregiverInviteRepository(prefs, now: () => now);
      final invite = await repo.createInvite();
      if (state == 'redeemed') repo.simulateRedeemed(invite.token);
      if (state == 'expired') now = now.add(const Duration(minutes: 11));
      await repo.cancelAllInvites();
      repo.dispose();
      final reopened = FakeCaregiverInviteRepository(prefs, now: () => now);
      expect(await reopened.getActiveInvite(), isNull);
      final next = await reopened.createInvite();
      expect(await reopened.getActiveInvite(), isNotNull);
      expect(next.expiresAt.isAfter(now), isTrue);
      reopened.dispose();
    });
  }
}
