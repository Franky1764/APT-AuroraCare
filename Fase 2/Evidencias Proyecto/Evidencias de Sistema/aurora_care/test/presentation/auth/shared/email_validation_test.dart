import 'package:flutter_test/flutter_test.dart';
import 'package:aurora_care/presentation/auth/shared/email_validation.dart';

void main() {
  test('acepta correos habituales, alias y espacios exteriores', () {
    for (final email in [
      ' rosa@correo.cl ',
      'ana+familia@gmail.com',
      'ana.perez@sub.dominio.cl',
      "o'connor@example.org",
    ]) {
      expect(EmailValidation.isValid(email), isTrue, reason: email);
    }
  });
  test(
    'rechaza puntos inválidos, dominios incompletos y espacios internos',
    () {
      for (final email in [
        '',
        'ana',
        'ana@@correo.cl',
        '.ana@correo.cl',
        'ana..perez@correo.cl',
        'ana.@correo.cl',
        'ana@-correo.cl',
        'ana@correo-.cl',
        'ana@correo..cl',
        'ana@correo.c',
        'ana perez@correo.cl',
        'ana@correo_cl.com',
      ]) {
        expect(EmailValidation.isValid(email), isFalse, reason: email);
      }
    },
  );
  test('sugiere errores conocidos sin cambiar dominios particulares', () {
    expect(EmailValidation.suggestion('ana@gmial.com'), 'ana@gmail.com');
    expect(EmailValidation.suggestion('ana@empresa.cl'), isNull);
    expect(EmailValidation.suggestion('correo incorrecto'), isNull);
  });
}
