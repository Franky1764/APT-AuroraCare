import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:aurora_care/core/router/navigation_session.dart';
import 'package:aurora_care/data/sources/privacy_actions_platform.dart';
import 'package:aurora_care/domain/entities/privacy_data.dart';
import 'package:aurora_care/domain/entities/privacy_request.dart';
import 'package:aurora_care/domain/entities/session_info.dart';
import 'package:aurora_care/domain/repositories/privacy_repository.dart';
import 'package:aurora_care/presentation/privacy/privacy_providers.dart';
import 'package:aurora_care/presentation/privacy/privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Navigation extends NavigationSessionNotifier {
  @override
  NavigationSession build() => const NavigationSession(
    initialized: true,
    session: SessionInfo(
      uid: 'owner',
      email: 'owner@example.test',
      currentMode: 2,
    ),
  );
}

class _Repository implements PrivacyRepository {
  String name = 'Ana';
  int deletions = 0;
  String? password;
  bool consent = true;
  @override
  Future<PrivacyData> readData() async => PrivacyData(
    name: name,
    email: 'owner@example.test',
    consent: consent,
    json: '{"account":{"name":"Ana"}}',
    hasUnassignedHistory: false,
  );
  @override
  Future<void> correctName(String name) async {
    this.name = name;
  }

  @override
  Future<void> withdrawConsent() async {
    consent = false;
  }

  @override
  Future<void> delete(PrivacyDeletion deletion, String password) async {
    expect(deletion, PrivacyDeletion.history);
    deletions++;
    this.password = password;
  }
}

class _Platform extends PrivacyActionsPlatform {
  String? saved;
  @override
  Future<bool> saveData(String json) async {
    saved = json;
    return true;
  }
}

void main() {
  Future<void> open(
    WidgetTester tester,
    _Repository repository,
    _Platform platform,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationSessionProvider.overrideWith(_Navigation.new),
          privacyRepositoryProvider.overrideWithValue(repository),
          privacyActionsProvider.overrideWithValue(platform),
          pendingPrivacyDeletionProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: PrivacyScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('corrige el nombre y prepara una descarga con confirmación', (
    tester,
  ) async {
    final repository = _Repository();
    final platform = _Platform();
    await open(tester, repository, platform);
    final edit = find.text('Corregir mi nombre');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Elena');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repository.name, 'Elena');
    expect(tester.takeException(), isNull);

    final download = find.text('Descargar mis datos');
    await tester.ensureVisible(download);
    await tester.tap(download);
    await tester.pumpAndSettle();
    expect(platform.saved, isNull);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(platform.saved, contains('"account"'));
  });

  testWidgets(
    'cancelar la eliminación conserva los datos; confirmar exige contraseña',
    (tester) async {
      final repository = _Repository();
      await open(tester, repository, _Platform());
      final delete = find.text('Borrar mi historial y conservar mi cuenta');
      await tester.scrollUntilVisible(
        delete,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repository.deletions, 0);
      await tester.scrollUntilVisible(
        delete,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirmar eliminación'));
      await tester.tap(find.text('Confirmar eliminación'));
      await tester.pumpAndSettle();
      expect(repository.deletions, 0);
      await tester.enterText(find.byType(TextField), 'secret');
      await tester.tap(find.text('Confirmar eliminación'));
      await tester.pumpAndSettle();
      expect(repository.deletions, 1);
      expect(repository.password, 'secret');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'la política incluida identifica a la responsable y el canal de privacidad',
    (tester) async {
      final policy = jsonDecode(
        await rootBundle.loadString('assets/privacy/privacy_policy.json'),
      ) as Map;
      expect(policy['responsible'], 'Daniela Castillo Gallegos');
      expect(policy['email'], PrivacyRequest.contact);
      expect(policy['address'], 'Santiago de Chile');
      expect((policy['sections'] as List).length, greaterThan(5));
    },
  );

  test('una segunda acción no confirma una operación que sigue en curso', () async {
    final container = ProviderContainer(overrides: [
      privacyRepositoryProvider.overrideWithValue(_Repository()),
      pendingPrivacyDeletionProvider.overrideWith((ref) => null),
    ]);
    addTearDown(container.dispose);
    final action = container.read(privacyActionProvider.notifier);
    final pending = Completer<void>();
    final first = action.run((repository) => pending.future);
    final second = await action.run((repository) async {});
    expect(second, false);
    pending.complete();
    expect(await first, true);
  });

  test('las dos solicitudes de eliminación tienen alcances distintos', () {
    const history = PrivacyRequest(
      right: PrivacyRight.deleteHistory,
      details: '',
    );
    const account = PrivacyRequest(
      right: PrivacyRight.deleteAccount,
      details: '',
    );
    expect(history.body, contains('conservar mi cuenta'));
    expect(account.body, contains('eliminar mi cuenta'));
    expect(history.body, isNot(contains('secret')));
    expect(PrivacyRequest.contact, 'auroracareprivacidad@gmail.com');
  });
}
