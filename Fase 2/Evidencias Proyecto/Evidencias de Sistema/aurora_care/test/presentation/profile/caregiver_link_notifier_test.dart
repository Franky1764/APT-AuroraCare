import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurora_care/core/firebase_providers.dart';
import 'package:aurora_care/data/repositories/fake_caregiver_invite_repository.dart';
import 'package:aurora_care/domain/repositories/caregiver_invite_repository.provider.dart';
import 'package:aurora_care/presentation/profile/caregiver_link_notifier.dart';

Future<ProviderContainer> _contenedor({DateTime Function()? now}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      caregiverInviteRepositoryProvider.overrideWith((ref) {
        final repo = FakeCaregiverInviteRepository(prefs, now: now);
        ref.onDispose(repo.dispose);
        return repo;
      }),
    ],
  );
  return container;
}

void main() {
  test('sin invitación previa, build() llega a status none', () async {
    final container = await _contenedor();
    addTearDown(container.dispose);

    final state = await container.read(caregiverLinkProvider.future);

    expect(state.status, CaregiverLinkViewStatus.none);
    expect(state.invite, isNull);
  });

  test(
    'generar() crea una invitación y pasa a status active con el token '
    'nuevo',
    () async {
      final container = await _contenedor();
      addTearDown(container.dispose);
      container.listen(caregiverLinkProvider, (_, _) {});
      await container.read(caregiverLinkProvider.future);

      await container.read(caregiverLinkProvider.notifier).generar();

      final state = container.read(caregiverLinkProvider).value!;
      expect(state.status, CaregiverLinkViewStatus.active);
      expect(state.invite, isNotNull);
    },
  );

  test(
    'al reabrir con una invitación activa ya creada, build() llega a '
    'active con el expiresAt original (sigue descontando, no reinicia '
    'un contador)',
    () async {
      var ahora = DateTime(2026, 1, 1, 12, 0, 0);
      final container = await _contenedor(now: () => ahora);
      addTearDown(container.dispose);
      container.listen(caregiverLinkProvider, (_, _) {});
      await container.read(caregiverLinkProvider.future);

      await container.read(caregiverLinkProvider.notifier).generar();
      final invite = container.read(caregiverLinkProvider).value!.invite!;

      // Simula "reabrir la app": un ProviderContainer nuevo, misma
      // SharedPreferences, el reloj avanzó 2 minutos.
      ahora = ahora.add(const Duration(minutes: 2));
      final nuevoContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            container.read(sharedPreferencesProvider),
          ),
          caregiverInviteRepositoryProvider.overrideWith((ref) {
            final repo = FakeCaregiverInviteRepository(
              container.read(sharedPreferencesProvider),
              now: () => ahora,
            );
            ref.onDispose(repo.dispose);
            return repo;
          }),
        ],
      );
      addTearDown(nuevoContainer.dispose);

      final estadoReabierto = await nuevoContainer.read(
        caregiverLinkProvider.future,
      );

      expect(estadoReabierto.status, CaregiverLinkViewStatus.active);
      expect(estadoReabierto.invite?.token, invite.token);
      expect(estadoReabierto.invite?.expiresAt, invite.expiresAt);
    },
  );

  test(
    'cuando watchInvite informa expired, el estado pasa a expired',
    () async {
      final container = await _contenedor();
      addTearDown(container.dispose);
      container.listen(caregiverLinkProvider, (_, _) {});
      await container.read(caregiverLinkProvider.future);
      await container.read(caregiverLinkProvider.notifier).generar();
      await Future<void>.delayed(Duration.zero);

      final repo =
          container.read(caregiverInviteRepositoryProvider)
              as FakeCaregiverInviteRepository;
      final token = container.read(caregiverLinkProvider).value!.invite!.token;
      await repo.cancelInvite(token);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(caregiverLinkProvider).value!;
      expect(state.status, CaregiverLinkViewStatus.expired);
    },
  );

  test(
    'cuando watchInvite informa redeemed, el estado pasa a redeemed',
    () async {
      final container = await _contenedor();
      addTearDown(container.dispose);
      container.listen(caregiverLinkProvider, (_, _) {});
      await container.read(caregiverLinkProvider.future);
      await container.read(caregiverLinkProvider.notifier).generar();
      // El fake entrega el estado inicial ("active") de forma diferida
      // (scheduleMicrotask) al suscribirse. Si se dispara otro cambio de
      // estado sincrónicamente (simulateRedeemed no es async), ese
      // envío diferido podría llegar DESPUÉS y pisar el estado nuevo.
      // Se vacía la cola de microtasks antes de seguir para evitar esa
      // carrera — exclusivo de este fake de prueba.
      await Future<void>.delayed(Duration.zero);

      final repo =
          container.read(caregiverInviteRepositoryProvider)
              as FakeCaregiverInviteRepository;
      final token = container.read(caregiverLinkProvider).value!.invite!.token;
      repo.simulateRedeemed(token);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(caregiverLinkProvider).value!;
      expect(state.status, CaregiverLinkViewStatus.redeemed);
    },
  );

  test('cancelar() vuelve al estado none', () async {
    final container = await _contenedor();
    addTearDown(container.dispose);
    container.listen(caregiverLinkProvider, (_, _) {});
    await container.read(caregiverLinkProvider.future);
    await container.read(caregiverLinkProvider.notifier).generar();

    await container.read(caregiverLinkProvider.notifier).cancelar();

    final state = container.read(caregiverLinkProvider).value!;
    expect(state.status, CaregiverLinkViewStatus.none);
    expect(state.invite, isNull);
  });
}
