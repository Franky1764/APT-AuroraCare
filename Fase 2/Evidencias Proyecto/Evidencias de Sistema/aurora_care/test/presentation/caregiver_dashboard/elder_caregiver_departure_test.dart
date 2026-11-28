import 'package:aurora_care/presentation/caregiver_dashboard/elder_caregiver_departure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const token = 'abc';

  test('avisa cuando el cuidador termina el vínculo', () {
    final notice = evaluateCaregiverDeparture(
      token: token,
      link: {'status': 'revoked', 'revokedBy': 'caregiver', 'caregiverName': 'Ana'},
      alreadyNotifiedToken: null,
    );
    expect(notice, isNotNull);
    expect(notice!.title, 'Su cuidador terminó el vínculo');
    expect(notice.message, startsWith('Ana ya no verá'));
  });

  test('sin nombre usa «Su cuidador»', () {
    final notice = evaluateCaregiverDeparture(
      token: token,
      link: {'status': 'revoked', 'revokedBy': 'caregiver'},
      alreadyNotifiedToken: null,
    );
    expect(notice!.message, startsWith('Su cuidador ya no verá'));
  });

  test('no avisa si el vínculo sigue activo', () {
    expect(
      evaluateCaregiverDeparture(
        token: token,
        link: {'status': 'active'},
        alreadyNotifiedToken: null,
      ),
      isNull,
    );
  });

  test('no avisa si lo terminó el propio adulto mayor', () {
    expect(
      evaluateCaregiverDeparture(
        token: token,
        link: {'status': 'revoked'},
        alreadyNotifiedToken: null,
      ),
      isNull,
    );
  });

  test('avisa una sola vez por vínculo', () {
    expect(
      evaluateCaregiverDeparture(
        token: token,
        link: {'status': 'revoked', 'revokedBy': 'caregiver'},
        alreadyNotifiedToken: token,
      ),
      isNull,
    );
  });

  test('el mensaje no usa palabras prohibidas', () {
    final notice = evaluateCaregiverDeparture(
      token: token,
      link: {'status': 'revoked', 'revokedBy': 'caregiver'},
      alreadyNotifiedToken: null,
    )!;
    final text = '${notice.title} ${notice.message}'.toLowerCase();
    for (final word in ['deterioro', 'demencia', 'diagnóstico', 'problema', 'enfermedad']) {
      expect(text, isNot(contains(word)));
    }
  });
}
