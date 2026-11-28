import 'package:flutter_test/flutter_test.dart';

import 'package:aurora_care/presentation/auth/shared/password_policy.dart';

void main() {
  group('PasswordPolicy.evaluate — campo vacío', () {
    test('strength=empty, isValid=false, sin issues, requisitos pendientes', () {
      final e = PasswordPolicy.evaluate('');
      expect(e.strength, PasswordStrength.empty);
      expect(e.isValid, isFalse);
      expect(e.issues, isEmpty);
      expect(e.requirements, hasLength(4));
      expect(e.requirements.every((r) => !r.met), isTrue);
    });
  });

  group('PasswordPolicy.evaluate — longitud', () {
    test('8 caracteres (muy corta): débil, mensaje "faltan 4"', () {
      final e = PasswordPolicy.evaluate('Abcdefg1');
      expect(e.strength, PasswordStrength.weak);
      expect(e.isValid, isFalse);
      expect(e.issues, contains('Te faltan 4 caracteres (mínimo 12).'));
    });

    test('borde: 11 caracteres no alcanza (falta 1)', () {
      final e = PasswordPolicy.evaluate('Abcdefghij1'); // 11
      expect(e.requirements.first.met, isFalse);
      expect(e.issues, contains('Te falta 1 carácter (mínimo 12).'));
      expect(e.strength, PasswordStrength.weak); // nunca llega a mínimo
    });

    test('borde: 12 caracteres exactos sí alcanza', () {
      final e = PasswordPolicy.evaluate('Abcdefghij12'); // 12
      expect(e.requirements.first.met, isTrue);
      expect(e.issues, isEmpty);
      expect(e.isValid, isTrue);
    });

    test('borde: 20 caracteres exactos sigue siendo válida', () {
      final e = PasswordPolicy.evaluate('Abcdefghijklmnopqr12'); // 20
      expect(e.requirements.first.met, isTrue);
      expect(e.isValid, isTrue);
    });

    test('borde: 21 caracteres sobra 1, mensaje "sobran 1 carácter"', () {
      final e = PasswordPolicy.evaluate('Abcdefghijklmnopqr123'); // 21
      expect(e.requirements.first.met, isFalse);
      expect(e.issues, contains('Te sobra 1 carácter (máximo 20).'));
      expect(e.isValid, isFalse);
    });

    test('más de 20: mensaje "sobran N caracteres" con N correcto', () {
      final e = PasswordPolicy.evaluate('Abcdefghijklmnopqr12345'); // 23
      expect(e.issues, contains('Te sobran 3 caracteres (máximo 20).'));
      expect(e.isValid, isFalse);
    });
  });

  group('PasswordPolicy.evaluate — mayúscula/minúscula/número', () {
    test('sin mayúscula: mensaje correspondiente, el resto válido', () {
      final e = PasswordPolicy.evaluate('abcdefghij12');
      expect(e.issues, ['Falta al menos una letra mayúscula.']);
      expect(e.isValid, isFalse);
    });

    test('sin minúscula: mensaje correspondiente', () {
      final e = PasswordPolicy.evaluate('ABCDEFGHIJ12');
      expect(e.issues, ['Falta al menos una letra minúscula.']);
      expect(e.isValid, isFalse);
    });

    test('sin número: mensaje correspondiente', () {
      final e = PasswordPolicy.evaluate('AbcdefghijkL');
      expect(e.issues, ['Falta al menos un número.']);
      expect(e.isValid, isFalse);
    });

    test('faltan varios a la vez: todos los mensajes aplicables aparecen', () {
      final e = PasswordPolicy.evaluate('abc'); // corta, sin mayús, sin número
      expect(e.issues, [
        'Te faltan 9 caracteres (mínimo 12).',
        'Falta al menos una letra mayúscula.',
        'Falta al menos un número.',
      ]);
    });
  });

  group('PasswordPolicy.evaluate — carácter especial (no obligatorio)', () {
    test('sin carácter especial, 12 caracteres: válida pero no "muy fuerte"', () {
      final e = PasswordPolicy.evaluate('Abcdefghij12'); // 12, sin especial
      expect(e.isValid, isTrue);
      expect(e.strength, PasswordStrength.strong);
    });

    test('con carácter especial, 12 caracteres: "muy fuerte"', () {
      final e = PasswordPolicy.evaluate('Abcdefghi1!'); // 11... ajustar a 12
      // 12 caracteres con especial:
      final e2 = PasswordPolicy.evaluate('Abcdefghi1!2');
      expect(e2.isValid, isTrue);
      expect(e2.strength, PasswordStrength.veryStrong);
      // El caso de 11 no es válido (muy corto): confirma que el
      // especial no compensa la longitud mínima.
      expect(e.isValid, isFalse);
    });

    test('16 o más caracteres sin especial: "muy fuerte" igual', () {
      final e = PasswordPolicy.evaluate('Abcdefghijklmno1'); // 16, sin especial
      expect(e.isValid, isTrue);
      expect(e.strength, PasswordStrength.veryStrong);
    });

    test('15 caracteres sin especial: válida pero solo "fuerte"', () {
      final e = PasswordPolicy.evaluate('Abcdefghijklmn1'); // 15
      expect(e.isValid, isTrue);
      expect(e.strength, PasswordStrength.strong);
    });
  });

  group('PasswordPolicy.evaluate — niveles del medidor', () {
    test(
      'débil: no llega al mínimo de longitud aunque cumpla los otros 3',
      () {
        // Mayúscula, minúscula y número presentes, pero muy corta.
        final e = PasswordPolicy.evaluate('Ab1');
        expect(e.strength, PasswordStrength.weak);
      },
    );

    test('débil: longitud ok pero cumple 2 o menos de los 4', () {
      // Longitud ok (12) y número, pero sin mayúscula ni minúscula
      // (dígitos no cuentan como mayúscula/minúscula) -> cumple 2 de 4.
      final e = PasswordPolicy.evaluate('123456789012');
      expect(e.strength, PasswordStrength.weak);
    });

    test('media: cumple 3 de los 4 (longitud ok, falta solo 1)', () {
      final e = PasswordPolicy.evaluate('abcdefghij12'); // sin mayúscula
      expect(e.strength, PasswordStrength.medium);
      expect(e.isValid, isFalse);
    });

    test('fuerte: cumple los 4, sin ser "muy fuerte"', () {
      final e = PasswordPolicy.evaluate('Abcdefghij12'); // 12, sin especial
      expect(e.strength, PasswordStrength.strong);
    });

    test('muy fuerte: cumple los 4 y tiene carácter especial', () {
      final e = PasswordPolicy.evaluate('Abcdefghi1!2');
      expect(e.strength, PasswordStrength.veryStrong);
    });
  });

  group('PasswordPolicy — requisitos (checklist)', () {
    test('las etiquetas son las 4 esperadas, en orden', () {
      final e = PasswordPolicy.evaluate('');
      expect(e.requirements.map((r) => r.label), [
        'De 12 a 20 caracteres',
        'Una letra mayúscula',
        'Una letra minúscula',
        'Un número',
      ]);
    });
  });
}
