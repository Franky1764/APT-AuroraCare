// lib/presentation/auth/shared/password_policy.dart

/// Política de contraseñas configurada en Firebase Authentication
/// (proyecto DuocAuroraCare): de [minLength] a [maxLength] caracteres,
/// con mayúscula, minúscula y número obligatorios. El carácter especial
/// NO es obligatorio, pero cuenta para [PasswordStrength.veryStrong].
///
/// Firebase está en modo "Notificar aplicación": deja registrar una
/// contraseña que no cumple y no bloquea por sí solo — por eso esta
/// clase valida ANTES de enviar nada a Firebase, con el mismo lenguaje
/// que se muestra si Firebase de todos modos la rechaza (código
/// 'password-does-not-meet-requirements').
///
/// Dart puro, sin Flutter: se puede probar y reutilizar sin widgets.
class PasswordPolicy {
  PasswordPolicy._();

  static const int minLength = 12;
  static const int maxLength = 20;

  /// Desde esta longitud, una contraseña que ya cumple los 4
  /// obligatorios pasa a "Muy fuerte" aunque no tenga un carácter
  /// especial.
  static const int veryStrongLength = 16;

  /// Cuántos de los 4 requisitos obligatorios alcanzan para "Media" en
  /// vez de "Débil" (ver [_strengthFor]).
  static const int _mediumRequirementCount = 3;

  static final RegExp _uppercase = RegExp('[A-ZÁÉÍÓÚÑ]');
  static final RegExp _lowercase = RegExp('[a-záéíóúñ]');
  static final RegExp _digit = RegExp('[0-9]');
  static final RegExp _special = RegExp(r'[^A-Za-zÁÉÍÓÚÑáéíóúñ0-9]');

  /// Evalúa [password] contra la política completa: la lista de
  /// requisitos (para el checklist), los mensajes detallados de lo que
  /// falta o sobra, el nivel del medidor de seguridad, y si ya se puede
  /// enviar el formulario.
  static PasswordEvaluation evaluate(String password) {
    if (password.isEmpty) {
      return PasswordEvaluation(
        requirements: _requirements(password),
        issues: const [],
        strength: PasswordStrength.empty,
        isValid: false,
      );
    }

    final hasMinLength = password.length >= minLength;
    final hasMaxLength = password.length <= maxLength;
    final hasUppercase = _uppercase.hasMatch(password);
    final hasLowercase = _lowercase.hasMatch(password);
    final hasDigit = _digit.hasMatch(password);
    final hasSpecial = _special.hasMatch(password);

    final issues = <String>[];
    if (!hasMinLength) {
      final faltan = minLength - password.length;
      issues.add(
        'Te ${_falta(faltan)} $faltan ${_caracteres(faltan)} '
        '(mínimo $minLength).',
      );
    } else if (!hasMaxLength) {
      final sobran = password.length - maxLength;
      issues.add(
        'Te ${_sobra(sobran)} $sobran ${_caracteres(sobran)} '
        '(máximo $maxLength).',
      );
    }
    if (!hasUppercase) issues.add('Falta al menos una letra mayúscula.');
    if (!hasLowercase) issues.add('Falta al menos una letra minúscula.');
    if (!hasDigit) issues.add('Falta al menos un número.');

    // Los 4 requisitos obligatorios: longitud dentro del rango,
    // mayúscula, minúscula, número. El carácter especial no es
    // obligatorio — solo suma para "Muy fuerte".
    final metRequired = [
      hasMinLength && hasMaxLength,
      hasUppercase,
      hasLowercase,
      hasDigit,
    ];
    final metCount = metRequired.where((met) => met).length;
    final isValid = metCount == metRequired.length;

    final strength = _strengthFor(
      metCount: metCount,
      isValid: isValid,
      hasMinLength: hasMinLength,
      length: password.length,
      hasSpecial: hasSpecial,
    );

    return PasswordEvaluation(
      requirements: _requirements(password),
      issues: issues,
      strength: strength,
      isValid: isValid,
    );
  }

  /// Débil: no llega a [minLength] (sin importar cuántos otros
  /// requisitos cumpla), o cumple 2 o menos de los 4 obligatorios.
  /// Media: cumple 3 de los 4. Fuerte: cumple los 4. Muy fuerte: cumple
  /// los 4 y además tiene un carácter especial o [veryStrongLength] o
  /// más caracteres.
  static PasswordStrength _strengthFor({
    required int metCount,
    required bool isValid,
    required bool hasMinLength,
    required int length,
    required bool hasSpecial,
  }) {
    if (!hasMinLength) return PasswordStrength.weak;
    if (isValid) {
      final veryStrong = hasSpecial || length >= veryStrongLength;
      return veryStrong ? PasswordStrength.veryStrong : PasswordStrength.strong;
    }
    if (metCount >= _mediumRequirementCount) return PasswordStrength.medium;
    return PasswordStrength.weak;
  }

  static String _caracteres(int cantidad) =>
      cantidad == 1 ? 'carácter' : 'caracteres';

  static String _falta(int cantidad) => cantidad == 1 ? 'falta' : 'faltan';

  static String _sobra(int cantidad) => cantidad == 1 ? 'sobra' : 'sobran';

  static List<PasswordRequirement> _requirements(String password) {
    return [
      PasswordRequirement(
        label: 'De $minLength a $maxLength caracteres',
        met: password.length >= minLength && password.length <= maxLength,
      ),
      PasswordRequirement(
        label: 'Una letra mayúscula',
        met: _uppercase.hasMatch(password),
      ),
      PasswordRequirement(
        label: 'Una letra minúscula',
        met: _lowercase.hasMatch(password),
      ),
      PasswordRequirement(label: 'Un número', met: _digit.hasMatch(password)),
    ];
  }
}

/// Nivel del medidor de seguridad. [empty] es un estado aparte (campo
/// vacío): no es "débil", es "todavía no hay nada que medir".
enum PasswordStrength { empty, weak, medium, strong, veryStrong }

/// Un requisito del checklist bajo el campo de contraseña.
class PasswordRequirement {
  const PasswordRequirement({required this.label, required this.met});

  final String label;
  final bool met;
}

/// Resultado completo de evaluar una contraseña contra [PasswordPolicy].
class PasswordEvaluation {
  const PasswordEvaluation({
    required this.requirements,
    required this.issues,
    required this.strength,
    required this.isValid,
  });

  /// Los 4 requisitos obligatorios, con su estado (✓/○) — para el
  /// checklist siempre visible.
  final List<PasswordRequirement> requirements;

  /// Mensajes detallados de lo que falta o sobra en este momento, en el
  /// orden: longitud, mayúscula, minúscula, número. Vacía si ya es
  /// válida o si el campo está vacío.
  final List<String> issues;

  final PasswordStrength strength;

  /// true solo cuando se cumplen los 4 requisitos obligatorios (el
  /// carácter especial no es uno de ellos).
  final bool isValid;
}
