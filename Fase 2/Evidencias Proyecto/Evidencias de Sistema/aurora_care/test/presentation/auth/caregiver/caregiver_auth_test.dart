import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/core/router/navigation_session.dart';
import 'package:aurora_care/domain/entities/session_info.dart';
import 'package:aurora_care/domain/entities/account_role.dart';
import 'package:aurora_care/domain/repositories/caregiver_account_repository.dart';
import 'package:aurora_care/domain/exceptions/caregiver_auth_exception.dart';
import 'package:aurora_care/data/repositories/caregiver_account_repository.provider.dart';
import 'package:aurora_care/presentation/auth/caregiver/caregiver_login_screen.dart';
import 'package:aurora_care/presentation/auth/caregiver/caregiver_register_screen.dart';

class Accounts implements CaregiverAccountRepository {
  final response = Completer<SessionInfo>();
  int calls = 0;
  String? savedName, savedEmail;
  @override
  Future<SessionInfo> login({required String email, required String password}) {
    calls++;
    savedEmail = email;
    return response.future;
  }

  @override
  Future<SessionInfo> register({
    required String name,
    required String email,
    required String password,
  }) {
    savedName = name;
    return login(email: email, password: password);
  }
}

void main() {
  for (final registering in [false, true]) {
    testWidgets(
      'caregiver ${registering ? 'registration' : 'login'} waits for real confirmation',
      (tester) async {
        final accounts = Accounts();
        var completed = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              caregiverAccountRepositoryProvider.overrideWithValue(accounts),
            ],
            child: MaterialApp(
              home: registering
                  ? CaregiverRegisterScreen(
                      onRegisterSuccess: () => completed++,
                    )
                  : CaregiverLoginScreen(onLoginSuccess: () => completed++),
            ),
          ),
        );
        final fields = find.byType(TextFormField);
        if (registering) {
          await tester.enterText(fields.at(0), 'Persona cuidadora');
        }
        await tester.enterText(
          fields.at(registering ? 1 : 0),
          'caregiver@example.test',
        );
        await tester.enterText(
          fields.at(registering ? 2 : 1),
          // Login no valida la política de contraseñas; registro sí
          // (ver password_policy.dart) y necesita una contraseña válida
          // para que el botón se habilite.
          registering ? 'Cuidadora12345' : 'secret123',
        );
        if (registering) {
          // El botón "Crear cuenta" se habilita recién cuando la
          // contraseña es válida: hace falta un pump() para que ese
          // setState() se refleje antes de tocarlo.
          await tester.pump();
        }
        final label = registering ? 'Crear cuenta' : 'Entrar';
        await tester.ensureVisible(find.widgetWithText(ElevatedButton, label));
        await tester.tap(find.widgetWithText(ElevatedButton, label));
        await tester.pump();
        expect(completed, 0);
        expect(accounts.calls, 1);
        expect(find.text('Un momento…'), findsOneWidget);
        accounts.response.complete(
          const SessionInfo(
            uid: 'caregiver',
            email: 'caregiver@example.test',
            role: AccountRole.caregiver,
          ),
        );
        await tester.pumpAndSettle();
        expect(completed, 1);
        final container = ProviderScope.containerOf(
          tester.element(
            find.byType(
              registering ? CaregiverRegisterScreen : CaregiverLoginScreen,
            ),
          ),
        );
        expect(
          container.read(navigationSessionProvider).session!.role,
          AccountRole.caregiver,
        );
      },
    );
  }
  testWidgets(
    'invalid credentials do not navigate or reveal raw Firebase error',
    (tester) async {
      final accounts = Accounts();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            caregiverAccountRepositoryProvider.overrideWithValue(accounts),
          ],
          child: const MaterialApp(home: CaregiverLoginScreen()),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'caregiver@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      accounts.response.completeError(
        const CaregiverAuthException(CaregiverAuthFailure.invalidCredentials),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Revise su correo y contraseña e intente de nuevo.'),
        findsOneWidget,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CaregiverLoginScreen)),
      );
      expect(container.read(navigationSessionProvider).session, isNull);
    },
  );
}
